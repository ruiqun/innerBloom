//
//  SubscriptionSyncService.swift
//  innerBloom
//
//  B-033: 帳號級別 Premium 訂閱同步服務
//  職責：購買後上報 transaction 到後端、登入後查詢帳號 Premium 狀態、失敗重試
//

import Foundation
import StoreKit

// MARK: - 後端響應模型

struct SubscriptionSyncResponse: Codable {
    let success: Bool?
    let is_premium: Bool
    let is_in_trial: Bool?
    let expires_at: String?
    let product_id: String?
    let error: String?
}

// MARK: - 待上報 Transaction

struct PendingTransactionReport: Codable {
    let originalTransactionId: String
    let transactionId: String
    let productId: String
    let purchaseDate: Date
    let expiresAt: Date?
    let isInTrial: Bool
    let environment: String
}

// MARK: - SubscriptionSyncService

final class SubscriptionSyncService {
    
    static let shared = SubscriptionSyncService()
    
    private let config = SupabaseConfig.shared
    private let session: URLSession
    private let pendingReportsKey = "com.innerbloom.pendingTransactionReports"
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - 上報 Transaction（購買/恢復成功後呼叫）
    
    func reportTransaction(_ transaction: Transaction) async {
        let report = PendingTransactionReport(
            originalTransactionId: String(transaction.originalID),
            transactionId: String(transaction.id),
            productId: transaction.productID,
            purchaseDate: transaction.originalPurchaseDate,
            expiresAt: transaction.expirationDate,
            isInTrial: transaction.offer?.type == .introductory,
            environment: transaction.environment.rawValue
        )
        
        let result = await sendReport(report)
        switch result {
        case .success: break
        case .subscriptionAlreadyLinked: break // 不加入待重試
        case .retryableFailure:
            savePendingReport(report)
            print("[SubscriptionSync] ⚠️ Report failed, saved for retry")
        }
    }
    
    // MARK: - 查詢帳號 Premium 狀態（登入後 / 啟動時呼叫）
    
    func fetchAccountPremiumStatus() async -> PremiumStatus? {
        guard config.isConfigured else { return nil }
        guard let token = await AuthManager.shared.getValidAccessToken() else { return nil }
        
        guard let url = URL(string: "\(config.projectURL)/functions/v1/subscription-sync") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("[SubscriptionSync] ❌ Query failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }
            
            let result = try JSONDecoder().decode(SubscriptionSyncResponse.self, from: data)
            
            var status = PremiumStatus()
            status.isPremium = result.is_premium
            status.isInTrial = result.is_in_trial ?? false
            status.lastSyncAt = Date()
            
            if let expiresStr = result.expires_at {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                status.expiresAt = formatter.date(from: expiresStr) ?? ISO8601DateFormatter().date(from: expiresStr)
            }
            
            print("[SubscriptionSync] ✅ Account status: premium=\(result.is_premium), trial=\(result.is_in_trial ?? false)")
            return status
            
        } catch {
            print("[SubscriptionSync] ❌ Query error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 重試之前失敗的上報
    
    func retryPendingReports() async {
        let pending = loadPendingReports()
        guard !pending.isEmpty else { return }
        
        print("[SubscriptionSync] 🔄 Retrying \(pending.count) pending reports...")
        
        var remaining: [PendingTransactionReport] = []
        
        for report in pending {
            let result = await sendReport(report)
            if case .retryableFailure = result {
                remaining.append(report)
            }
            // .success / .subscriptionAlreadyLinked 都不再重試
        }
        
        if remaining.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingReportsKey)
            print("[SubscriptionSync] ✅ All pending reports sent")
        } else {
            savePendingReports(remaining)
            print("[SubscriptionSync] ⚠️ \(remaining.count) reports still pending")
        }
    }
    
    // MARK: - 上報所有當前有效的 Entitlements（恢復購買用）
    
    func reportAllCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == "com.innerbloom.premium.monthly" ||
                  transaction.productID == "com.innerbloom.premium.yearly" else { continue }
            guard transaction.revocationDate == nil else { continue }
            
            await reportTransaction(transaction)
        }
    }
    
    // MARK: - Private: 發送上報請求
    
    private enum ReportResult {
        case success
        case retryableFailure
        case subscriptionAlreadyLinked
    }
    
    private func sendReport(_ report: PendingTransactionReport) async -> ReportResult {
        guard config.isConfigured else { return .retryableFailure }
        guard let token = await AuthManager.shared.getValidAccessToken() else { return .retryableFailure }
        
        guard let url = URL(string: "\(config.projectURL)/functions/v1/subscription-sync") else { return .retryableFailure }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var body: [String: Any] = [
            "original_transaction_id": report.originalTransactionId,
            "transaction_id": report.transactionId,
            "product_id": report.productId,
            "purchase_date": formatter.string(from: report.purchaseDate),
            "is_in_trial": report.isInTrial,
            "environment": report.environment,
        ]
        
        if let expiresAt = report.expiresAt {
            body["expires_at"] = formatter.string(from: expiresAt)
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .retryableFailure
            }
            if (200...299).contains(httpResponse.statusCode) {
                print("[SubscriptionSync] ✅ Reported: product=\(report.productId)")
                return .success
            }
            // 409：此訂閱已與其他帳號綁定，不需重試
            if httpResponse.statusCode == 409 {
                print("[SubscriptionSync] ⛔ Subscription already linked to another account")
                return .subscriptionAlreadyLinked
            }
            return .retryableFailure
        } catch {
            print("[SubscriptionSync] ❌ Send error: \(error.localizedDescription)")
            return .retryableFailure
        }
    }
    
    // MARK: - Private: Pending Reports 持久化
    
    private func savePendingReport(_ report: PendingTransactionReport) {
        var existing = loadPendingReports()
        existing.removeAll { $0.originalTransactionId == report.originalTransactionId }
        existing.append(report)
        savePendingReports(existing)
    }
    
    private func savePendingReports(_ reports: [PendingTransactionReport]) {
        let data = try? JSONEncoder().encode(reports)
        UserDefaults.standard.set(data, forKey: pendingReportsKey)
    }
    
    private func loadPendingReports() -> [PendingTransactionReport] {
        guard let data = UserDefaults.standard.data(forKey: pendingReportsKey),
              let reports = try? JSONDecoder().decode([PendingTransactionReport].self, from: data) else {
            return []
        }
        return reports
    }
}
