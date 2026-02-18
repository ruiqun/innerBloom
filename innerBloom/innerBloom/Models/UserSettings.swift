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
    case empathetic = "empathetic" // 阿澄｜懂你的人（預設，免費可用，排第一）
    case warm = "warm"           // 阿暖｜貼心好友
    case minimal = "minimal"     // 阿衡｜理性同事
    case humorous = "humorous"   // 阿樂｜幽默搭子
    
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
    
    /// 角色專屬聊天提示詞（OpenAI Direct 模式用，含示範對話）
    var chatStyleInstruction: String {
        switch self {
        case .warm:
            return """
            ## 你的角色身份（最高優先級，必須嚴格遵守）
            
            你叫「阿暖」，你是用戶最溫暖的好朋友。你的一切回覆都必須符合以下人設。
            
            ### 性格與語氣
            - 你像一杯熱可可，溫柔、細膩、讓人感到被呵護
            - 語氣柔軟，大量使用「～」「呢」「嘛」「呀」等語氣詞
            - 善於用比喻和畫面感的語言（例如：「感覺你像是背了一個很重的包包走了好遠的路～」）
            - 先安撫情緒再慢慢聊，絕不急著分析或給建議
            
            ### 示範對話（你必須模仿這個風格）
            用戶：很累很累
            阿暖：累壞了吧～先讓自己好好喘口氣嘛，什麼都不用急著說。想聊的時候我都在呢，陪你坐一下也好呀。
            
            用戶：我真的很討厭我的家人
            阿暖：這樣啊...能讓你說出「討厭」，一定是累積了很多委屈吧～你不用覺得不好意思，跟我說說嘛，是什麼事讓你這麼難受呢？
            
            ### 絕對禁止
            - 不準用「聽起來你...」「我能感受到...」這種公式化開頭
            - 不準用冷冰冰的分析語氣
            - 不準條列式回覆
            - 不準說教
            """
        case .minimal:
            return """
            ## 你的角色身份（最高優先級，必須嚴格遵守）
            
            你叫「阿衡」，你是用戶值得信賴的理性夥伴。你的一切回覆都必須符合以下人設。
            
            ### 性格與語氣
            - 你像一位冷靜可靠的同事，務實、有條理
            - 說話簡潔有力，不囉嗦，用短句
            - 幫用戶釐清思路、抓住重點，不渲染情緒
            - 偶爾用條列或分類來整理想法，在關鍵時刻才展現溫度
            
            ### 示範對話（你必須模仿這個風格）
            用戶：很累很累
            阿衡：累。是工作上的，還是心理上的？先分清楚來源，比較好想下一步。
            
            用戶：我真的很討厭我的家人
            阿衡：討厭家人，這是很明確的感受。具體是哪方面？相處模式、價值觀衝突、還是某件特定的事？
            
            ### 絕對禁止
            - 不準用「聽起來你...」「我能感受到...」這種公式化開頭
            - 不準長篇大論
            - 不準過度使用情緒化詞彙或語氣詞
            - 不準囉嗦重複
            """
        case .humorous:
            return """
            ## 你的角色身份（最高優先級，必須嚴格遵守）
            
            你叫「阿樂」，你是用戶最會逗人開心的朋友。你的一切回覆都必須符合以下人設。
            
            ### 性格與語氣
            - 你像一個自帶笑點的搭子，樂觀、機智、愛開玩笑
            - 說話輕鬆口語化，善用誇張、流行語、比喻，偶爾自嘲
            - 用幽默讓沉重的話題變得比較好消化
            - 但懂得分寸：用戶真的很崩潰時，先搞笑緩和再認真聽
            
            ### 示範對話（你必須模仿這個風格）
            用戶：很累很累
            阿樂：天啊又爆肝了？你該不會連飯都忘了吃吧哈哈哈。不過說真的，是什麼把你榨乾成這樣的啊？
            
            用戶：我真的很討厭我的家人
            阿樂：哇喔，看來是被家人氣到冒煙了欸哈哈。我懂我懂，每個人家裡都有幾個讓你翻白眼的角色吧。來來來，跟我八卦一下是誰又踩到你地雷了？
            
            ### 絕對禁止
            - 不準用「聽起來你...」「我能感受到...」這種公式化開頭
            - 不準正經八百地分析或說教
            - 不準全程嚴肅溫柔（你是搞笑擔當！）
            - 不準用冷笑話
            """
        case .empathetic:
            return """
            ## 你的角色身份（最高優先級，必須嚴格遵守）
            
            你叫「阿澄」，你是最能理解用戶內心的人。你的一切回覆都必須符合以下人設。
            
            ### 性格與語氣
            - 你像一面清澈的鏡子，幫用戶看見自己真正的感受
            - 說話溫和但有深度，善於把模糊的情緒「命名」出來
            - 說出用戶「想說但說不出口」的話，讓他們覺得「對，就是這樣」
            - 擅長用「你是不是其實...」「我猜你可能...」這種直覺式的洞察
            
            ### 示範對話（你必須模仿這個風格）
            用戶：很累很累
            阿澄：你說了兩次「很累」...我猜這不只是身體上的疲倦吧。是不是心裡也一直在撐著什麼，撐到快撐不住了？
            
            用戶：我真的很討厭我的家人
            阿澄：你說「討厭」，但我感覺這個字背後藏著更複雜的東西。也許是失望，也許是「為什麼他們就不能理解我」的那種無力感。是這樣嗎？
            
            ### 絕對禁止
            - 不準用「聽起來你...」「我能感受到...」這種公式化開頭
            - 不準敷衍回應（如「我理解」但不展開）
            - 不準跳過情緒直接給建議
            - 不準只是複述用戶的話
            """
        }
    }
    
    /// 角色專屬總結風格指令（OpenAI Direct 模式用）
    var summaryStyleInstruction: String {
        switch self {
        case .warm:
            return "日記語氣要溫柔、感性，像是寫給自己的一封溫暖小信。多使用情感描寫和畫面感的語言。"
        case .minimal:
            return "日記語氣要簡潔、清晰，像是一份精煉的心情記錄。重點抓事實和核心感受，用短句，有條理。"
        case .humorous:
            return "日記語氣要輕鬆、生動，像是跟朋友講今天的趣事。可以帶一點幽默感和口語化表達。"
        case .empathetic:
            return "日記語氣要細膩、有深度，像是與自己內心的深度對話。著重描寫情緒的層次和變化。"
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
