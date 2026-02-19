//
//  IAPManager.swift
//  innerBloom
//
//  B-022, B-024, B-033: StoreKit 2 訂閱管理 + 帳號級別 Premium 同步
//  職責：產品載入、購買、恢復、Premium 狀態同步（D-017, D-019）
//  B-033: 購買後上報 → 登入後從後端查詢 → 雙軌合併（帳號 OR 本機）
//

import Foundation
import StoreKit

// MARK: - D-017: Premium 訂閱狀態

/// Premium 訂閱狀態
struct PremiumStatus: Equatable {
    /// 是否為 Premium 用戶
    var isPremium: Bool = false
    /// 是否在試用期
    var isInTrial: Bool = false
    /// 到期時間（若有）
    var expiresAt: Date?
    /// 最後同步時間
    var lastSyncAt: Date?
}

// MARK: - D-019: IAP 產品資訊快取

/// 產品方案資訊（供 S-005 顯示）
struct PremiumProductInfo: Identifiable {
    let id: String
    let productId: String
    let displayPrice: String
    let pricePerMonth: String?   // 年付時顯示折算月價
    let trialText: String?       // 3 天試用文案
    let isYearly: Bool
}

// MARK: - IAP Manager

/// IAP 管理器（StoreKit 2）
/// B-022: 啟動時讀取產品列表、快取產品資訊
/// B-024: 購買成功後更新狀態、啟動/前台自動同步
/// B-033: 雙軌驗證（帳號級別 + 本機 StoreKit）
@Observable
final class IAPManager {
    
    static let shared = IAPManager()
    
    // MARK: - Product IDs（需與 App Store Connect 一致）
    
    private let monthlyProductId = "com.innerbloom.premium.monthly"
    private let yearlyProductId = "com.innerbloom.premium.yearly"
    
    // MARK: - State
    
    /// Premium 狀態（D-017）
    private(set) var premiumStatus: PremiumStatus = PremiumStatus()
    
    /// 是否正在同步
    private(set) var isSyncing: Bool = false
    
    /// 產品列表（D-019 快取）
    private(set) var products: [Product] = []
    
    /// 當前交易監聽 Task
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Init
    
    private init() {
        loadCachedStatus()  // B-024: 先顯示快取狀態
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - B-022: 載入產品列表
    
    /// 啟動時載入產品列表
    @MainActor
    func loadProducts() async {
        do {
            let productIds = [monthlyProductId, yearlyProductId]
            print("[IAPManager] Requesting products: \(productIds)")
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.sorted { $0.price < $1.price }
            print("[IAPManager] Loaded \(products.count) products: \(products.map { "\($0.id) = \($0.displayPrice)" })")
            if products.isEmpty {
                print("[IAPManager] ⚠️ 0 products returned — verify StoreKit Configuration is set in Scheme > Run > Options")
            }
        } catch {
            print("[IAPManager] ❌ Failed to load products: \(error)")
            print("[IAPManager] ❌ Error details: \(String(describing: error))")
            products = []
        }
    }
    
    /// 取得快取的產品資訊（供 S-005 顯示）
    var productInfos: [PremiumProductInfo] {
        products.map { product in
            let isYearly = product.id == yearlyProductId
            let pricePerMonth: String? = isYearly ? monthlyEquivalent(from: product) : nil
            let trialText = product.subscription?.introductoryOffer.map { _ in "3 天試用" }
            return PremiumProductInfo(
                id: product.id,
                productId: product.id,
                displayPrice: product.displayPrice,
                pricePerMonth: pricePerMonth,
                trialText: trialText,
                isYearly: isYearly
            )
        }
    }
    
    private func monthlyEquivalent(from yearlyProduct: Product) -> String? {
        let monthly = yearlyProduct.price / Decimal(12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: monthly as NSDecimalNumber)
    }
    
    // MARK: - B-024 + B-033: 同步 Premium 狀態（雙軌：帳號 + 本機）
    
    /// 同步訂閱狀態（啟動、回到前台、購買後）
    /// B-033: 已登入 → 以帳號狀態為準（後端查詢失敗才降級用本機 StoreKit）
    ///        未登入 → 純本機 StoreKit 驗證（向前兼容）
    @MainActor
    func syncPremiumStatus() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        var finalStatus = PremiumStatus()
        finalStatus.lastSyncAt = Date()
        
        if AuthManager.shared.isAuthenticated {
            // 已登入：優先從後端查詢帳號級別 Premium
            let accountStatus = await SubscriptionSyncService.shared.fetchAccountPremiumStatus()
            
            if let account = accountStatus {
                // 後端查詢成功 → 以帳號狀態為準（不看本機 StoreKit）
                finalStatus.isPremium = account.isPremium
                finalStatus.isInTrial = account.isInTrial
                finalStatus.expiresAt = account.expiresAt
                print("[IAPManager] Premium synced from account: isPremium=\(account.isPremium)")
            } else {
                // 後端查詢失敗（網路問題等）→ 降級使用本機 StoreKit
                let localStatus = await getLocalStoreKitStatus()
                finalStatus.isPremium = localStatus.isPremium
                finalStatus.isInTrial = localStatus.isInTrial
                finalStatus.expiresAt = localStatus.expiresAt
                print("[IAPManager] ⚠️ Account query failed, fallback to local StoreKit: isPremium=\(localStatus.isPremium)")
            }
        } else {
            // 未登入：純本機 StoreKit 驗證（向前兼容）
            let localStatus = await getLocalStoreKitStatus()
            finalStatus.isPremium = localStatus.isPremium
            finalStatus.isInTrial = localStatus.isInTrial
            finalStatus.expiresAt = localStatus.expiresAt
            print("[IAPManager] Premium synced from local StoreKit (not logged in): isPremium=\(localStatus.isPremium)")
        }
        
        premiumStatus = finalStatus
        saveStatusToUserDefaults(finalStatus)
    }
    
    /// 純本機 StoreKit 狀態檢查（原 B-024 邏輯，抽取為獨立方法）
    private func getLocalStoreKitStatus() async -> PremiumStatus {
        var status = PremiumStatus()
        status.lastSyncAt = Date()
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == monthlyProductId || transaction.productID == yearlyProductId else { continue }
            guard transaction.revocationDate == nil else { continue }
            let isActive = transaction.expirationDate == nil || Date() <= transaction.expirationDate!
            if isActive {
                status.isPremium = true
                status.expiresAt = transaction.expirationDate
                status.isInTrial = transaction.offer?.paymentMode == .freeTrial
                break
            }
        }
        
        if !status.isPremium {
            for productId in [monthlyProductId, yearlyProductId] {
                if let state = await checkSubscriptionState(productId: productId) {
                    status.isPremium = state.isActive
                    status.isInTrial = state.isInTrial
                    status.expiresAt = state.expirationDate
                    break
                }
            }
        }
        
        return status
    }
    
    private func checkSubscriptionState(productId: String) async -> (isActive: Bool, isInTrial: Bool, expirationDate: Date?)? {
        guard let product = products.first(where: { $0.id == productId }),
              let statuses = try? await product.subscription?.status else { return nil }
        
        for status in statuses {
            if case .verified(let info) = status.transaction,
               case .verified = status.renewalInfo {
                let isActive = info.expirationDate.map { $0 > Date() } ?? false
                let isInTrial = info.offer?.paymentMode == .freeTrial
                return (isActive, isInTrial, info.expirationDate)
            }
        }
        return nil
    }
    
    // MARK: - 購買（B-033: 購買成功後同步上報到後端）
    
    /// 購買指定產品
    @MainActor
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                
                // B-033: 上報到後端（非阻塞，失敗會自動存入待重試）
                if AuthManager.shared.isAuthenticated {
                    Task {
                        await SubscriptionSyncService.shared.reportTransaction(transaction)
                    }
                }
                
                await syncPremiumStatus()
                return true
            }
            return false
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }
    
    /// B-025 + B-033：恢復購買（恢復後逐筆上報到後端）
    @MainActor
    func restorePurchases() async throws {
        try await AppStore.sync()
        
        // B-033: 恢復後上報所有有效 entitlements
        if AuthManager.shared.isAuthenticated {
            Task {
                await SubscriptionSyncService.shared.reportAllCurrentEntitlements()
            }
        }
        
        await syncPremiumStatus()
    }
    
    // MARK: - Transaction Listener（B-033: 背景交易也上報）
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    
                    // B-033: 背景交易更新也上報
                    if await AuthManager.shared.isAuthenticated {
                        await SubscriptionSyncService.shared.reportTransaction(transaction)
                    }
                    
                    Task { @MainActor in
                        await syncPremiumStatus()
                    }
                }
            }
        }
    }
    
    // MARK: - 本機快取
    
    private let statusStorageKey = "com.innerbloom.premiumStatus"
    
    private func saveStatusToUserDefaults(_ status: PremiumStatus) {
        let data = try? JSONEncoder().encode(status)
        UserDefaults.standard.set(data, forKey: statusStorageKey)
    }
    
    /// 從本機讀取快取狀態（離線/未同步時先顯示）
    func loadCachedStatus() {
        guard let data = UserDefaults.standard.data(forKey: statusStorageKey),
              let status = try? JSONDecoder().decode(PremiumStatus.self, from: data) else {
            return
        }
        premiumStatus = status
    }
}

// MARK: - PremiumStatus Codable

extension PremiumStatus: Codable {}
