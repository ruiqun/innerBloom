//
//  UsageManager.swift
//  innerBloom
//
//  B-026: 免費用量管理器（F-020 + D-018）
//  - 每篇日記最多 4 次互動（免費）
//  - 每日最多 1 次總結（免費）
//  - Premium 使用者不受限制
//

import Foundation

/// 免費用量管理器
@Observable
final class UsageManager {
    
    // MARK: - Singleton
    static let shared = UsageManager()
    
    // MARK: - 限制常數
    
    /// 免費每篇日記最大互動次數
    static let freeInteractionLimit = 4
    /// 免費每日最大總結次數
    static let freeDailySummaryLimit = 1
    
    // MARK: - 狀態
    
    /// 當前日記已互動次數（使用者送出一次 = 1 次）
    private(set) var currentDiaryInteractionCount: Int = 0
    
    /// 今日已使用的總結次數
    private(set) var todaySummaryCount: Int = 0
    
    /// 上次總結的日期（用於跨日重置）
    private var lastSummaryDateString: String = ""
    
    // MARK: - UserDefaults Keys
    private let summaryCountKey = "com.innerbloom.dailySummaryCount"
    private let summaryDateKey = "com.innerbloom.dailySummaryDate"
    
    // MARK: - Init
    
    private init() {
        loadDailySummaryCount()
    }
    
    // MARK: - 互動次數（Per-Diary）
    
    /// 重置當前日記互動次數（進入新日記建立模式時呼叫）
    func resetDiaryInteraction() {
        currentDiaryInteractionCount = 0
        print("[UsageManager] Diary interaction count reset")
    }
    
    /// 記錄一次互動
    func recordInteraction() {
        currentDiaryInteractionCount += 1
        print("[UsageManager] Interaction recorded: \(currentDiaryInteractionCount)/\(UsageManager.freeInteractionLimit)")
    }
    
    /// 檢查是否還能互動（免費用戶用）
    /// - Returns: true = 可以繼續互動
    func canInteract() -> Bool {
        if IAPManager.shared.premiumStatus.isPremium {
            return true
        }
        return currentDiaryInteractionCount < UsageManager.freeInteractionLimit
    }
    
    /// 剩餘互動次數（免費用戶）
    var remainingInteractions: Int {
        if IAPManager.shared.premiumStatus.isPremium {
            return Int.max
        }
        return max(0, UsageManager.freeInteractionLimit - currentDiaryInteractionCount)
    }
    
    // MARK: - 每日總結次數
    
    /// 檢查今日是否還能生成總結
    /// - Returns: true = 可以生成
    func canGenerateSummary() -> Bool {
        if IAPManager.shared.premiumStatus.isPremium {
            return true
        }
        checkAndResetIfNewDay()
        return todaySummaryCount < UsageManager.freeDailySummaryLimit
    }
    
    /// 記錄一次總結使用
    func recordSummary() {
        checkAndResetIfNewDay()
        todaySummaryCount += 1
        saveDailySummaryCount()
        print("[UsageManager] Summary recorded: \(todaySummaryCount)/\(UsageManager.freeDailySummaryLimit)")
    }
    
    /// 今日剩餘總結次數
    var remainingSummaries: Int {
        if IAPManager.shared.premiumStatus.isPremium {
            return Int.max
        }
        checkAndResetIfNewDay()
        return max(0, UsageManager.freeDailySummaryLimit - todaySummaryCount)
    }
    
    // MARK: - 跨日重置
    
    /// 取得今日的日期字串（yyyy-MM-dd）
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
    
    /// 檢查是否跨日，若是則重置計數
    private func checkAndResetIfNewDay() {
        let today = todayString()
        if lastSummaryDateString != today {
            todaySummaryCount = 0
            lastSummaryDateString = today
            saveDailySummaryCount()
            print("[UsageManager] New day detected, summary count reset")
        }
    }
    
    // MARK: - 持久化
    
    private func saveDailySummaryCount() {
        UserDefaults.standard.set(todaySummaryCount, forKey: summaryCountKey)
        UserDefaults.standard.set(lastSummaryDateString, forKey: summaryDateKey)
    }
    
    private func loadDailySummaryCount() {
        todaySummaryCount = UserDefaults.standard.integer(forKey: summaryCountKey)
        lastSummaryDateString = UserDefaults.standard.string(forKey: summaryDateKey) ?? ""
        checkAndResetIfNewDay()
        print("[UsageManager] Loaded: summaryCount=\(todaySummaryCount), date=\(lastSummaryDateString)")
    }
}
