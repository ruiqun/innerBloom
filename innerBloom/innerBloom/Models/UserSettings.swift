//
//  UserSettings.swift
//  innerBloom
//
//  用户设定模型 - D-007
//  B-016: 深色模式与多语言预留
//  B-017: 多语言功能实现
//

import Foundation

/// 外观模式 (D-007)
/// B-016: 当前版本强制使用深色模式，外观设置隐藏
enum AppearanceMode: String, Codable, CaseIterable {
    case dark = "dark"         // 深色模式
    case light = "light"       // 浅色模式（预留）
    
    /// B-017: 本地化显示名称
    var displayName: String {
        switch self {
        case .dark: return String.localized(.darkMode)
        case .light: return String.localized(.lightMode)
        }
    }
    
    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

/// 陪伴角色 (D-022, B-029)
/// 原 AIToneStyle，改為「陪伴角色」呈現（不出現 AI 字樣）
/// F-025: 阿暖、阿衡、阿樂、阿澄
enum AIToneStyle: String, Codable, CaseIterable {
    case warm = "warm"           // 阿暖｜貼心好友
    case minimal = "minimal"     // 阿衡｜理性同事
    case humorous = "humorous"   // 阿樂｜幽默搭子
    case empathetic = "empathetic" // 阿澄｜懂你的人（預設）
    
    /// B-017: 本地化显示名称
    var displayName: String {
        switch self {
        case .warm: return String.localized(.toneWarm)
        case .minimal: return String.localized(.toneMinimal)
        case .humorous: return String.localized(.toneHumorous)
        case .empathetic: return String.localized(.toneEmpathetic)
        }
    }
    
    /// B-029: 角色名稱（如「阿暖」）
    var roleName: String {
        switch self {
        case .warm: return String.localized(.roleNameWarm)
        case .minimal: return String.localized(.roleNameMinimal)
        case .humorous: return String.localized(.roleNameHumorous)
        case .empathetic: return String.localized(.roleNameEmpathetic)
        }
    }
    
    /// B-029: 角色標籤（如「貼心好友」）
    var roleTag: String {
        switch self {
        case .warm: return String.localized(.roleTagWarm)
        case .minimal: return String.localized(.roleTagMinimal)
        case .humorous: return String.localized(.roleTagHumorous)
        case .empathetic: return String.localized(.roleTagEmpathetic)
        }
    }
    
    /// B-017: 本地化描述
    var description: String {
        switch self {
        case .warm: return String.localized(.toneWarmDesc)
        case .minimal: return String.localized(.toneMinimalDesc)
        case .humorous: return String.localized(.toneHumorousDesc)
        case .empathetic: return String.localized(.toneEmpatheticDesc)
        }
    }
    
    /// B-029: 示例回覆（S-007 角色卡片用）
    var exampleReply: String {
        switch self {
        case .warm: return String.localized(.roleExampleWarm)
        case .minimal: return String.localized(.roleExampleMinimal)
        case .humorous: return String.localized(.roleExampleHumorous)
        case .empathetic: return String.localized(.roleExampleEmpathetic)
        }
    }
    
    var icon: String {
        switch self {
        case .warm: return "heart.fill"
        case .minimal: return "doc.text"
        case .humorous: return "face.smiling"
        case .empathetic: return "hands.clap.fill"
        }
    }
    
    /// AI 系统提示词指令（B-016：用于 AI Service）
    /// 注意：此处保持中文，因为是给 AI 的指令，不需要本地化
    var systemPromptInstruction: String {
        switch self {
        case .warm:
            return "请用温暖、治愈、富有同理心的语气。多关注情感共鸣，像一个温柔的倾听者。"
        case .minimal:
            return "请用简洁、客观、理性的语气。多关注事实描述，像一个专业的记录者，不要过多的修饰词。"
        case .humorous:
            return "请用幽默、风趣、轻松的语气。可以适度调侃，像一个有趣的朋友，让对话充满快乐。"
        case .empathetic:
            return "请用深度共情、理解、支持的语气。专注于理解用户的感受，给予情感上的认同和支持。"
        }
    }
    
    /// 标签风格描述（用于标签生成）
    var tagStyleDescription: String {
        switch self {
        case .warm:
            return "温暖、感性、治愈"
        case .minimal:
            return "简洁、客观、名词为主"
        case .humorous:
            return "有趣、生动、带点幽默感"
        case .empathetic:
            return "情感化、共鸣、细腻"
        }
    }
}

/// 语言选项 (D-007 - 未来扩展)
enum AppLanguage: String, Codable, CaseIterable {
    case zhHant = "zh-Hant"      // 繁体中文
    case en = "en"               // English
    
    var displayName: String {
        switch self {
        case .zhHant: return "繁體中文"
        case .en: return "English"
        }
    }
    
    var flag: String {
        switch self {
        case .zhHant: return "🇹🇼"
        case .en: return "🇺🇸"
        }
    }
    
    /// AI 回复强制语言指令（注入到所有 system prompt）
    var aiLanguageInstruction: String {
        switch self {
        case .zhHant:
            return """
            ## 语言规则（最高优先级，不可违反）
            - 你必须始终使用「繁體中文」回覆，無論用戶使用什麼語言輸入。
            - 禁止使用簡體中文、英文或其他語言回覆。
            - 所有輸出（包括 JSON 中的文字值）都必須是繁體中文。
            """
        case .en:
            return """
            ## Language Rule (Highest Priority, Must Not Violate)
            - You MUST always reply in English, regardless of what language the user types in.
            - Do NOT reply in Chinese, Japanese, or any other language.
            - All output (including text values inside JSON) MUST be in English.
            """
        }
    }
}

/// 用户设定模型 (D-007)
struct UserSettings: Codable {
    
    // MARK: - 外观设定
    
    /// 外观模式（深色/浅色/跟随系统）
    var appearanceMode: AppearanceMode = .dark
    
    // MARK: - AI 设定
    
    /// 陪伴角色偏好 (D-021, B-029)
    /// F-025 預設：阿澄｜懂你的人
    var aiToneStyle: AIToneStyle = .empathetic
    
    /// 是否自动生成标题
    var autoGenerateTitle: Bool = true
    
    /// 是否自动生成标签
    var autoGenerateTags: Bool = true
    
    // MARK: - 语言设定（预留）
    
    /// App 语言
    var appLanguage: AppLanguage = .zhHant
    
    // MARK: - 隐私设定
    
    /// 是否允许发送媒体到 AI（用于隐私敏感用户）
    var allowMediaAnalysis: Bool = true
    
    /// 是否允许发送位置信息
    var allowLocationSharing: Bool = true
    
    // MARK: - 通知设定（预留）
    
    /// 是否开启每日提醒
    var enableDailyReminder: Bool = false
    
    /// 提醒时间（预留）
    var reminderTime: Date?
    
    // MARK: - 调试/开发者设定（内部使用）
    
    /// 显示模型供应商信息（只读展示）
    var showModelInfo: Bool = false
    
    // MARK: - 版本信息
    
    /// 设定版本（用于迁移）
    var settingsVersion: Int = 1
    
    /// 最后更新时间
    var lastUpdated: Date = Date()
    
    // MARK: - 初始化
    
    init() {}
    
    // MARK: - 便捷方法
    
    /// 更新最后修改时间
    mutating func touch() {
        lastUpdated = Date()
    }
    
    /// 重置为默认值
    mutating func resetToDefaults() {
        appearanceMode = .dark
        aiToneStyle = .empathetic
        autoGenerateTitle = true
        autoGenerateTags = true
        appLanguage = .zhHant
        allowMediaAnalysis = true
        allowLocationSharing = true
        enableDailyReminder = false
        reminderTime = nil
        showModelInfo = false
        touch()
    }
}

// MARK: - 默认实例

extension UserSettings {
    /// 默认设定
    static let `default` = UserSettings()
}
