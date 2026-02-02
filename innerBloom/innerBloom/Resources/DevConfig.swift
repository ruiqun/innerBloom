//
//  DevConfig.swift
//  innerBloom
//
//  开发者配置 - 用于调试和测试
//

import Foundation

/// 开发者配置
struct DevConfig {
    
    // MARK: - 开关
    
    /// 开发模式开关
    /// 打开时：每次启动 App 只保留最新一条数据，清理其余数据
    static let isDevelopmentMode: Bool = true
    
    /// 是否清理旧草稿（仅在开发模式下生效）
    static let cleanOldDrafts: Bool = true
    
    /// 是否清理云端旧日记（仅在开发模式下生效）
    /// ⚠️ 危险：会删除 Supabase 中的日记数据！
    static let cleanCloudDiaries: Bool = true
    
    /// 是否打印详细日志
    static let verboseLogging: Bool = true
    
    /// 是否已执行过云端清理（避免重复清理）
    private static var hasCleanedCloud = false
    
    /// 标记已清理
    static func markCloudCleaned() {
        hasCleanedCloud = true
    }
    
    /// 是否应该清理云端
    static var shouldCleanCloud: Bool {
        isDevelopmentMode && cleanCloudDiaries && !hasCleanedCloud
    }
    
    // MARK: - 调试信息
    
    static func printConfig() {
        guard verboseLogging else { return }
        print("[DevConfig] ═══════════════════════════════════════")
        print("[DevConfig] 🛠️  开发者配置")
        print("[DevConfig] ───────────────────────────────────────")
        print("[DevConfig]   开发模式: \(isDevelopmentMode ? "✅ 开启" : "❌ 关闭")")
        print("[DevConfig]   清理旧草稿: \(cleanOldDrafts ? "✅ 是" : "❌ 否")")
        print("[DevConfig]   清理云端日记: \(cleanCloudDiaries ? "⚠️ 是" : "❌ 否")")
        print("[DevConfig]   详细日志: \(verboseLogging ? "✅ 是" : "❌ 否")")
        print("[DevConfig] ═══════════════════════════════════════")
    }
}
