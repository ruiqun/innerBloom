//
//  SettingsManager.swift
//  innerBloom
//
//  用户设定管理器 - 本地存储与读取
//  B-016: 深色模式与多语言预留
//

import Foundation
import SwiftUI

/// 用户设定管理器
/// 使用 @Observable 宏（遵循 .cursorrules）
@Observable
final class SettingsManager {
    
    // MARK: - Singleton
    
    static let shared = SettingsManager()
    
    // MARK: - Properties
    
    /// 当前用户设定
    private(set) var settings: UserSettings = .default
    
    /// 是否已加载
    private(set) var isLoaded: Bool = false
    
    // MARK: - Private
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "com.innerbloom.userSettings"
    
    // MARK: - 初始化
    
    private init() {
        loadSettings()
        print("[SettingsManager] Initialized with settings version: \(settings.settingsVersion)")
    }
    
    // MARK: - 加载与保存
    
    /// 加载设定
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey) {
            do {
                let decoded = try JSONDecoder().decode(UserSettings.self, from: data)
                settings = decoded
                isLoaded = true
                print("[SettingsManager] Settings loaded successfully")
            } catch {
                print("[SettingsManager] Failed to decode settings: \(error), using defaults")
                settings = .default
                isLoaded = true
            }
        } else {
            print("[SettingsManager] No saved settings found, using defaults")
            settings = .default
            isLoaded = true
        }
    }
    
    /// 保存设定
    func saveSettings() {
        settings.touch()
        
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
            print("[SettingsManager] Settings saved successfully")
        } catch {
            print("[SettingsManager] Failed to encode settings: \(error)")
        }
    }
    
    /// 重置设定
    func resetSettings() {
        settings.resetToDefaults()
        saveSettings()
        print("[SettingsManager] Settings reset to defaults")
    }
    
    // MARK: - 外观设定
    
    /// 获取当前外观模式
    var appearanceMode: AppearanceMode {
        settings.appearanceMode
    }
    
    /// 设置外观模式
    func setAppearanceMode(_ mode: AppearanceMode) {
        settings.appearanceMode = mode
        saveSettings()
        applyAppearanceMode()
        print("[SettingsManager] Appearance mode changed to: \(mode.displayName)")
    }
    
    /// 应用外观模式到系统
    /// B-016: 当前版本强制使用深色模式
    func applyAppearanceMode() {
        // 获取所有 window scenes
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        for window in windowScene.windows {
            // B-016: 强制深色模式
            window.overrideUserInterfaceStyle = .dark
        }
        
        print("[SettingsManager] Applied appearance mode: dark (forced)")
    }
    
    /// 获取 SwiftUI ColorScheme（用于 preferredColorScheme）
    /// B-016: 当前版本强制使用深色模式
    var colorScheme: ColorScheme? {
        return .dark  // 强制深色模式
    }
    
    // MARK: - AI 设定
    
    /// 获取 AI 口吻风格
    var aiToneStyle: AIToneStyle {
        settings.aiToneStyle
    }
    
    /// 设置 AI 口吻风格
    func setAIToneStyle(_ style: AIToneStyle) {
        settings.aiToneStyle = style
        saveSettings()
        print("[SettingsManager] AI tone style changed to: \(style.displayName)")
    }
    
    /// 是否自动生成标题
    var autoGenerateTitle: Bool {
        settings.autoGenerateTitle
    }
    
    /// 设置是否自动生成标题
    func setAutoGenerateTitle(_ enabled: Bool) {
        settings.autoGenerateTitle = enabled
        saveSettings()
    }
    
    /// 是否自动生成标签
    var autoGenerateTags: Bool {
        settings.autoGenerateTags
    }
    
    /// 设置是否自动生成标签
    func setAutoGenerateTags(_ enabled: Bool) {
        settings.autoGenerateTags = enabled
        saveSettings()
    }
    
    // MARK: - 语言设定
    
    /// 获取 App 语言
    var appLanguage: AppLanguage {
        settings.appLanguage
    }
    
    /// 设置 App 语言
    /// B-017: 实现实际语言切换，即时生效
    func setAppLanguage(_ language: AppLanguage) {
        settings.appLanguage = language
        saveSettings()
        
        // B-017: 同步到 LocalizationManager，触发视图刷新
        LocalizationManager.shared.setLanguage(language)
        
        print("[SettingsManager] App language changed to: \(language.displayName)")
    }
    
    // MARK: - 隐私设定
    
    /// 是否允许媒体分析
    var allowMediaAnalysis: Bool {
        settings.allowMediaAnalysis
    }
    
    /// 设置是否允许媒体分析
    func setAllowMediaAnalysis(_ enabled: Bool) {
        settings.allowMediaAnalysis = enabled
        saveSettings()
    }
    
    /// 是否允许位置分享
    var allowLocationSharing: Bool {
        settings.allowLocationSharing
    }
    
    /// 设置是否允许位置分享
    func setAllowLocationSharing(_ enabled: Bool) {
        settings.allowLocationSharing = enabled
        saveSettings()
    }
    
    // MARK: - 开发者设定
    
    /// 是否显示模型信息
    var showModelInfo: Bool {
        settings.showModelInfo
    }
    
    /// 设置是否显示模型信息
    func setShowModelInfo(_ enabled: Bool) {
        settings.showModelInfo = enabled
        saveSettings()
    }
}
