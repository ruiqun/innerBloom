//
//  LocalizationManager.swift
//  innerBloom
//
//  多语言管理器 - B-017
//  支持繁体中文（默认）与英文切换
//

import Foundation
import SwiftUI

/// 多语言管理器
/// 使用 @Observable 宏实现响应式语言切换
@Observable
final class LocalizationManager {
    
    // MARK: - Singleton
    
    static let shared = LocalizationManager()
    
    // MARK: - Properties
    
    /// 当前语言
    private(set) var currentLanguage: AppLanguage = .zhHant
    
    /// 语言变更通知 ID（用于强制刷新视图）
    private(set) var languageChangeId: UUID = UUID()
    
    // MARK: - 初始化
    
    private init() {
        // 从 SettingsManager 同步当前语言设定
        syncFromSettings()
    }
    
    // MARK: - 公开方法
    
    /// 设置语言
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        
        currentLanguage = language
        languageChangeId = UUID()  // 触发视图刷新
        
        print("[LocalizationManager] Language changed to: \(language.displayName)")
    }
    
    /// 从设定同步语言
    func syncFromSettings() {
        let savedLanguage = SettingsManager.shared.appLanguage
        if savedLanguage != currentLanguage {
            currentLanguage = savedLanguage
            languageChangeId = UUID()
            print("[LocalizationManager] Synced language from settings: \(savedLanguage.displayName)")
        }
    }
    
    /// 获取本地化字符串
    func localized(_ key: L10nKey) -> String {
        return key.localized(for: currentLanguage)
    }
    
    /// 获取带参数的本地化字符串
    func localized(_ key: L10nKey, args: CVarArg...) -> String {
        let format = key.localized(for: currentLanguage)
        return String(format: format, arguments: args)
    }
}

// MARK: - 本地化字符串键

/// 所有可本地化的字符串键
enum L10nKey: String, CaseIterable {
    
    // MARK: - 通用
    case done = "done"
    case cancel = "cancel"
    case confirm = "confirm"
    case delete = "delete"
    case retry = "retry"
    case retryAll = "retry_all"
    case search = "search"
    case clear = "clear"
    case close = "close"
    case save = "save"
    case all = "all"
    case processing = "processing"
    case loading = "loading"
    case error = "error"
    case hint = "hint"
    case unknownError = "unknown_error"
    
    // MARK: - 主页
    case memory = "memory"
    case searchDiary = "search_diary"
    case noDiaryYet = "no_diary_yet"
    case swipeLeftToCreate = "swipe_left_to_create"
    case noDiaryInCategory = "no_diary_in_category"
    case searchResult = "search_result"
    case foundDiaries = "found_diaries"
    
    // MARK: - 同步状态
    case syncFailed = "sync_failed"
    case syncFailedCount = "sync_failed_count"
    case savedLocallyRetryLater = "saved_locally_retry_later"
    
    // MARK: - 创建模式
    case conversation = "conversation"
    case saveMemory = "save_memory"
    case generatingTitle = "generating_title"
    case generatingSummary = "generating_summary"
    case aiGenerating = "ai_generating"
    case uploading = "uploading"
    case saving = "saving"
    case noContent = "no_content"
    
    // MARK: - 输入区域
    case listening = "listening"
    case shareYourMood = "share_your_mood"
    case stopRecording = "stop_recording"
    case startVoiceInput = "start_voice_input"
    case tapToStopRecording = "tap_to_stop_recording"
    case tapToStartVoice = "tap_to_start_voice"
    case notSureWhatToSay = "not_sure_what_to_say"
    case moreMessages = "more_messages"
    
    // MARK: - 媒体区域
    case tapToUpload = "tap_to_upload"
    
    // MARK: - 媒体选择
    case selectPhotoOrVideo = "select_photo_or_video"
    case cannotReadPhoto = "cannot_read_photo"
    case cannotReadVideo = "cannot_read_video"
    case cannotGeneratePreview = "cannot_generate_preview"
    case photoReadFailed = "photo_read_failed"
    case videoReadFailed = "video_read_failed"
    
    // MARK: - 聊天
    case reply = "reply"
    case reviewConversation = "review_conversation"
    case conversationRecords = "conversation_records"
    case aiGeneratedTags = "ai_generated_tags"
    case aiViewOfImage = "ai_view_of_image"
    
    // MARK: - 日记详情
    case deleteDiary = "delete_diary"
    case mediaCannotPlay = "media_cannot_play"
    
    // MARK: - 设定页
    case settings = "settings"
    case companionRole = "companion_role"  // B-029: 陪伴角色（取代 aiToneStyle 文案）
    case companionRoleLockedHint = "companion_role_locked_hint"  // B-029: 非 Premium 提示
    case roleNameWarm = "role_name_warm"       // 阿暖
    case roleNameMinimal = "role_name_minimal" // 阿衡
    case roleNameHumorous = "role_name_humorous" // 阿樂
    case roleNameEmpathetic = "role_name_empathetic" // 阿澄
    case roleTagWarm = "role_tag_warm"         // 貼心好友
    case roleTagMinimal = "role_tag_minimal"   // 理性同事
    case roleTagHumorous = "role_tag_humorous" // 幽默搭子
    case roleTagEmpathetic = "role_tag_empathetic" // 懂你的人
    case roleExampleWarm = "role_example_warm"
    case roleExampleMinimal = "role_example_minimal"
    case roleExampleHumorous = "role_example_humorous"
    case roleExampleEmpathetic = "role_example_empathetic"
    case appearance = "appearance"
    case darkMode = "dark_mode"
    case lightMode = "light_mode"
    case aiAssistant = "ai_assistant"
    case aiToneStyle = "ai_tone_style"
    case autoGenerateTitle = "auto_generate_title"
    case autoGenerateTitleDesc = "auto_generate_title_desc"
    case autoGenerateTags = "auto_generate_tags"
    case autoGenerateTagsDesc = "auto_generate_tags_desc"
    case language = "language"
    case languageChangeNote = "language_change_note"
    case privacy = "privacy"
    case allowLocationSharing = "allow_location_sharing"
    case allowLocationSharingDesc = "allow_location_sharing_desc"
    case privacyPolicy = "privacy_policy"
    case about = "about"
    case version = "version"
    case buildNumber = "build_number"
    case resetAllSettings = "reset_all_settings"
    case developer = "developer"
    case showModelInfo = "show_model_info"
    case showModelInfoDesc = "show_model_info_desc"
    case currentModel = "current_model"
    case cloudService = "cloud_service"
    case connected = "connected"
    case notConfigured = "not_configured"
    
    // MARK: - AI 口吻风格
    case toneWarm = "tone_warm"
    case toneWarmDesc = "tone_warm_desc"
    case toneMinimal = "tone_minimal"
    case toneMinimalDesc = "tone_minimal_desc"
    case toneHumorous = "tone_humorous"
    case toneHumorousDesc = "tone_humorous_desc"
    case toneEmpathetic = "tone_empathetic"
    case toneEmpatheticDesc = "tone_empathetic_desc"
    
    // MARK: - 问候语 & 欢迎语 (B-017)
    case greetingEarlyMorning = "greeting_early_morning"
    case greetingMorning = "greeting_morning"
    case greetingNoon = "greeting_noon"
    case greetingAfternoon = "greeting_afternoon"
    case greetingEvening = "greeting_evening"
    case greetingNight = "greeting_night"
    
    case welcomePhotoInstant = "welcome_photo_instant"
    case welcomeVideoInstant = "welcome_video_instant"
    case welcomePhotoDefault = "welcome_photo_default"
    case welcomeVideoDefault = "welcome_video_default"
    
    case openerJoyfulPhoto = "opener_joyful_photo"
    case openerJoyfulVideo = "opener_joyful_video"
    case openerPeacefulPhoto = "opener_peaceful_photo"
    case openerPeacefulVideo = "opener_peaceful_video"
    case openerNostalgicPhoto = "opener_nostalgic_photo"
    case openerNostalgicVideo = "opener_nostalgic_video"
    case openerAdventurous = "opener_adventurous"
    case openerTagTravel = "opener_tag_travel"
    case openerTagFriends = "opener_tag_friends"
    case openerTagFood = "opener_tag_food"
    case openerDefaultPhoto = "opener_default_photo"
    case openerDefaultVideo = "opener_default_video"
    
    // MARK: - 登入/登出 (B-018)
    case login = "login"
    case logout = "logout"
    case signUp = "sign_up"
    case signIn = "sign_in"
    case email = "email"
    case password = "password"
    case verificationCode = "verification_code"
    case sendVerificationCode = "send_verification_code"
    case verifyAndLogin = "verify_and_login"
    case loginWithPassword = "login_with_password"
    case loginWithOTP = "login_with_otp"
    case enterEmail = "enter_email"
    case enterPassword = "enter_password"
    case enterVerificationCode = "enter_verification_code"
    case codeSent = "code_sent"
    case codeSentDesc = "code_sent_desc"
    case loginWelcome = "login_welcome"
    case loginSubtitle = "login_subtitle"
    case loginPrivacyHint = "login_privacy_hint"
    case loggingIn = "logging_in"
    case signingUp = "signing_up"
    case sendingCode = "sending_code"
    case verifying = "verifying"
    case logoutConfirm = "logout_confirm"
    case logoutConfirmDesc = "logout_confirm_desc"
    case account = "account"
    case currentAccount = "current_account"
    case notLoggedIn = "not_logged_in"
    case loginExpired = "login_expired"
    case loginExpiredDesc = "login_expired_desc"
    case noAccount = "no_account"
    case haveAccount = "have_account"
    case passwordMinLength = "password_min_length"
    case orContinueWith = "or_continue_with"
    case otpExpired = "otp_expired"
    case signUpSuccess = "sign_up_success"
    case signUpSuccessDesc = "sign_up_success_desc"
    case userAlreadyRegistered = "user_already_registered"
    
    // MARK: - 隐私政策
    case privacyPolicyTitle = "privacy_policy_title"
    case dataCollection = "data_collection"
    case dataCollectionContent = "data_collection_content"
    case dataUsage = "data_usage"
    case dataUsageContent = "data_usage_content"
    case dataSecurity = "data_security"
    case dataSecurityContent = "data_security_content"
    case yourRights = "your_rights"
    case yourRightsContent = "your_rights_content"
    case lastUpdated = "last_updated"
    
    // MARK: - B-022/B-023 Premium 付費牆
    case upgradePremium = "upgrade_premium"
    case premium = "premium"
    case premiumTitle = "premium_title"
    case premiumSubtitle = "premium_subtitle"
    case premiumBenefits = "premium_benefits"
    case premiumBenefitUnlimitedChat = "premium_benefit_unlimited_chat"
    case premiumBenefitUnlimitedSummary = "premium_benefit_unlimited_summary"
    case premiumBenefitPriority = "premium_benefit_priority"
    case premiumBenefitRoles = "premium_benefit_roles"
    case premiumMonthly = "premium_monthly"
    case premiumYearly = "premium_yearly"
    case premiumPerMonth = "premium_per_month"
    case premiumSubscribe = "premium_subscribe"
    case premiumSyncing = "premium_syncing"
    case restorePurchases = "restore_purchases"
    case restoreSuccess = "restore_success"
    case restoreNoPurchase = "restore_no_purchase"
    case restoreNoPurchaseHint = "restore_no_purchase_hint"
    case premiumProductsLoadHint = "premium_products_load_hint"
    case premiumRetryLoad = "premium_retry_load"
    case termsOfService = "terms_of_service"
    case subscriptionTerms = "subscription_terms"
    case premiumAlreadySubscribed = "premium_already_subscribed"
    case manageSubscription = "manage_subscription"
    case premiumExpiresOn = "premium_expires_on"
    case restoreCanceledHint = "restore_canceled_hint"
    
    // MARK: - B-026 用量限制
    case usageLimitTitle = "usage_limit_title"
    case usageLimitInteractionDesc = "usage_limit_interaction_desc"
    case usageLimitSummaryDesc = "usage_limit_summary_desc"
    case usageLimitDismiss = "usage_limit_dismiss"
    case usageInteractionHint = "usage_interaction_hint"
    case usageSummaryHint = "usage_summary_hint"
    
    // MARK: - B-027 Premium 優先佇列
    case premiumPriorityHint = "premium_priority_hint"
    
    // MARK: - B-020 稳定性相关
    case rateLimitMessage = "rate_limit_message"
    case loadingMore = "loading_more"
    case noMoreData = "no_more_data"
    
    // MARK: - 本地化方法
    
    /// 获取指定语言的本地化字符串
    func localized(for language: AppLanguage) -> String {
        switch language {
        case .zhHant:
            return zhHantValue
        case .en:
            return enValue
        }
    }
    
    /// 繁体中文值
    private var zhHantValue: String {
        switch self {
        // 通用
        case .done: return "完成"
        case .cancel: return "取消"
        case .confirm: return "確定"
        case .delete: return "刪除"
        case .retry: return "重試"
        case .retryAll: return "全部重試"
        case .search: return "搜尋"
        case .clear: return "清除"
        case .close: return "關閉"
        case .save: return "儲存"
        case .all: return "全部"
        case .processing: return "處理中..."
        case .loading: return "載入中..."
        case .error: return "錯誤"
        case .hint: return "提示"
        case .unknownError: return "發生未知錯誤"
            
        // 主页
        case .memory: return "InnerBloom"
        case .searchDiary: return "搜尋日記..."
        case .noDiaryYet: return "目前還沒有日記"
        case .swipeLeftToCreate: return "向左滑動開始記錄你的第一篇日記"
        case .noDiaryInCategory: return "這個分類還沒有日記"
        case .searchResult: return "搜尋結果"
        case .foundDiaries: return "找到 %d 篇日記"
            
        // 同步状态
        case .syncFailed: return "同步失敗"
        case .syncFailedCount: return "%d 篇日記同步失敗"
        case .savedLocallyRetryLater: return "已保留在本機，可點擊重試"
            
        // 创建模式
        case .conversation: return "對話"
        case .saveMemory: return "儲存回憶"
        case .generatingTitle: return "正在生成標題..."
        case .generatingSummary: return "正在為你書寫日記..."
        case .aiGenerating: return "正在為你書寫日記..."
        case .uploading: return "上傳中..."
        case .saving: return "儲存中..."
        case .noContent: return "無內容"
            
        // 媒体区域
        case .tapToUpload: return "點擊上傳"
            
        // 输入区域
        case .listening: return "正在聆聽..."
        case .shareYourMood: return "說說你的心情..."
        case .stopRecording: return "停止錄音"
        case .startVoiceInput: return "開始語音輸入"
        case .tapToStopRecording: return "點擊停止錄音並識別語音"
        case .tapToStartVoice: return "點擊開始語音輸入"
        case .notSureWhatToSay: return "不知道說什麼？試試這些："
        case .moreMessages: return "還有 %d 條訊息"
            
        // 媒体选择
        case .selectPhotoOrVideo: return "選擇照片/影片"
        case .cannotReadPhoto: return "無法讀取照片"
        case .cannotReadVideo: return "無法讀取影片"
        case .cannotGeneratePreview: return "無法生成影片預覽"
        case .photoReadFailed: return "照片讀取失敗："
        case .videoReadFailed: return "影片讀取失敗："
            
        // 聊天
        case .reply: return "回覆..."
        case .reviewConversation: return "回顧對話"
        case .conversationRecords: return "%d 條對話記錄"
        case .aiGeneratedTags: return "自動生成的標籤"
        case .aiViewOfImage: return "照片中的畫面"
            
        // 日记详情
        case .deleteDiary: return "刪除日記"
        case .mediaCannotPlay: return "媒體無法播放"
            
        // 设定页
        case .settings: return "設定"
        case .appearance: return "外觀"
        case .darkMode: return "深色模式"
        case .lightMode: return "淺色模式"
        case .aiAssistant: return "陪伴設定"
        case .aiToneStyle: return "口吻風格"
        case .autoGenerateTitle: return "自動生成標題"
        case .autoGenerateTitleDesc: return "儲存時自動為日記生成標題"
        case .autoGenerateTags: return "自動生成標籤"
        case .autoGenerateTagsDesc: return "儲存時自動為日記生成標籤"
        case .language: return "語言"
        case .languageChangeNote: return "切換語言後立即生效"
        case .privacy: return "隱私"
        case .allowLocationSharing: return "允許位置分享"
        case .allowLocationSharingDesc: return "可獲取當前位置以提供更貼心的陪伴"
        case .privacyPolicy: return "隱私政策"
        case .about: return "關於"
        case .version: return "版本"
        case .buildNumber: return "構建號"
        case .resetAllSettings: return "重置所有設定"
        case .developer: return "開發者"
        case .showModelInfo: return "顯示模型資訊"
        case .showModelInfoDesc: return "在日記詳情中顯示模型供應商"
        case .currentModel: return "當前模型"
        case .cloudService: return "雲端服務"
        case .connected: return "已連接"
        case .notConfigured: return "未配置"
            
        // B-029 陪伴角色
        case .companionRole: return "陪伴角色"
        case .companionRoleLockedHint: return "升級 Premium 可切換陪伴角色"
        case .roleNameWarm: return "阿暖"
        case .roleNameMinimal: return "阿衡"
        case .roleNameHumorous: return "阿樂"
        case .roleNameEmpathetic: return "阿澄"
        case .roleTagWarm: return "貼心好友"
        case .roleTagMinimal: return "理性同事"
        case .roleTagHumorous: return "幽默搭子"
        case .roleTagEmpathetic: return "懂你的人"
        case .roleExampleWarm: return "辛苦啦，先喘口氣～要不要跟我說說發生了什麼？"
        case .roleExampleMinimal: return "1. 發生的事 2. 你的感受 3. 接下來打算"
        case .roleExampleHumorous: return "哈哈這也太好笑了吧！所以後來呢？"
        case .roleExampleEmpathetic: return "我懂那種感覺。能多跟我說說，是什麼讓你這樣想嗎？"
            
        // AI 口吻风格
        case .toneWarm: return "溫暖治癒"
        case .toneWarmDesc: return "像好朋友一樣，給你溫暖的陪伴"
        case .toneMinimal: return "極簡客觀"
        case .toneMinimalDesc: return "簡潔客觀，專注記錄事實"
        case .toneHumorous: return "幽默風趣"
        case .toneHumorousDesc: return "輕鬆有趣，讓記錄充滿快樂"
        case .toneEmpathetic: return "共情理解"
        case .toneEmpatheticDesc: return "深度理解你的感受，給予共鳴"
            
        // 问候语 & 欢迎语
        case .greetingEarlyMorning: return "夜深了，還沒休息嗎？"
        case .greetingMorning: return "早安！新的一天開始了～ "
        case .greetingNoon: return "午安！吃過午飯了嗎？"
        case .greetingAfternoon: return "下午好！"
        case .greetingEvening: return "傍晚好！"
        case .greetingNight: return "晚上好！"
            
        case .welcomePhotoInstant: return "%@這張照片看起來很有故事！想聊聊是在什麼情況下拍的嗎？"
        case .welcomeVideoInstant: return "%@這段影片記錄了什麼特別的時刻呢？我很想聽你分享～"
        case .welcomePhotoDefault: return "這張照片看起來很有故事，能跟我說說嗎？"
        case .welcomeVideoDefault: return "這段影片記錄了什麼特別的時刻呢？"
            
        case .openerJoyfulPhoto: return "感受到這張照片裡的快樂氛圍了！能跟我分享一下嗎？"
        case .openerJoyfulVideo: return "感受到這段影片裡的快樂氛圍了！能跟我分享一下嗎？"
        case .openerPeacefulPhoto: return "這張照片給人很寧靜的感覺，是什麼讓你想記錄這個時刻？"
        case .openerPeacefulVideo: return "這段影片給人很寧靜的感覺，是什麼讓你想記錄這個時刻？"
        case .openerNostalgicPhoto: return "這張照片似乎有很多故事，願意跟我聊聊嗎？"
        case .openerNostalgicVideo: return "這段影片似乎有很多故事，願意跟我聊聊嗎？"
        case .openerAdventurous: return "看起來是一次很棒的經歷！能跟我說說發生了什麼嗎？"
        case .openerTagTravel: return "這是旅途中的風景嗎？看起來很美，能說說這趟旅程嗎？"
        case .openerTagFriends: return "和朋友在一起的時光總是特別的，這是什麼場合呢？"
        case .openerTagFood: return "看起來很好吃的樣子！這是在哪裡享用的？"
        case .openerDefaultPhoto: return "這張照片拍得很有感覺，能跟我說說背後的故事嗎？"
        case .openerDefaultVideo: return "這段影片記錄了什麼特別的時刻呢？我很想聽你分享。"
            
        // 登入/登出 (B-018)
        case .login: return "登入"
        case .logout: return "登出"
        case .signUp: return "註冊"
        case .signIn: return "登入"
        case .email: return "Email"
        case .password: return "密碼"
        case .verificationCode: return "驗證碼"
        case .sendVerificationCode: return "發送驗證碼"
        case .verifyAndLogin: return "驗證並登入"
        case .loginWithPassword: return "使用密碼登入"
        case .loginWithOTP: return "使用驗證碼登入"
        case .enterEmail: return "請輸入你的 Email"
        case .enterPassword: return "請輸入密碼"
        case .enterVerificationCode: return "請輸入驗證碼"
        case .codeSent: return "驗證碼已發送"
        case .codeSentDesc: return "驗證碼已發送到 %@，請查收信箱"
        case .loginWelcome: return "歡迎來到 InnerBloom"
        case .loginSubtitle: return "記錄生活，讓夥伴陪你聊聊"
        case .loginPrivacyHint: return ""
        case .loggingIn: return "登入中..."
        case .signingUp: return "註冊中..."
        case .sendingCode: return "發送中..."
        case .verifying: return "驗證中..."
        case .logoutConfirm: return "確定要登出嗎？"
        case .logoutConfirmDesc: return "登出後本機快取將被清除，但你的日記資料仍安全保存在雲端"
        case .account: return "帳號"
        case .currentAccount: return "目前帳號"
        case .notLoggedIn: return "未登入"
        case .loginExpired: return "登入已過期"
        case .loginExpiredDesc: return "請重新登入以繼續使用"
        case .noAccount: return "還沒有帳號？"
        case .haveAccount: return "已有帳號？"
        case .passwordMinLength: return "密碼至少 6 位"
        case .orContinueWith: return "或使用以下方式"
        case .otpExpired: return "驗證碼已過期，請重新發送"
        case .signUpSuccess: return "註冊成功"
        case .signUpSuccessDesc: return "帳號已建立，請登入"
        case .userAlreadyRegistered: return "此 Email 已註冊，請直接登入"
            
        // 隐私政策
        case .privacyPolicyTitle: return "隱私政策"
        case .dataCollection: return "資料收集"
        case .dataCollectionContent: return "• 我們收集您上傳的照片和影片，用於分析和日記生成\n• 我們收集您的對話內容，用於生成日記總結\n• 我們收集位置資訊（經您授權），用於提供更貼心的陪伴體驗"
        case .dataUsage: return "資料使用"
        case .dataUsageContent: return "• 您的媒體內容僅用於生成日記和陪伴對話\n• 您的資料會安全儲存在雲端（Supabase）\n• 我們不會將您的個人資料出售給第三方"
        case .dataSecurity: return "資料安全"
        case .dataSecurityContent: return "• 所有資料傳輸使用 HTTPS 加密\n• 媒體檔案儲存在安全的雲端儲存服務中\n• 您可以隨時刪除自己的日記和資料"
        case .yourRights: return "您的權利"
        case .yourRightsContent: return "• 您可以在設定中關閉媒體分析和位置分享\n• 您可以隨時刪除您的日記和相關資料\n• 您可以聯繫我們請求匯出或刪除所有資料"
        case .lastUpdated: return "最後更新：2024年12月"
            
        // B-022/B-023 Premium
        case .upgradePremium: return "升級 Premium"
        case .premium: return "Premium"
        case .premiumTitle: return "解鎖完整陪伴體驗"
        case .premiumSubtitle: return "不限聊天與總結，優先回覆，更多陪伴角色"
        case .premiumBenefits: return "Premium 權益"
        case .premiumBenefitUnlimitedChat: return "陪伴對話不限次數"
        case .premiumBenefitUnlimitedSummary: return "每日總結不限次數"
        case .premiumBenefitPriority: return "優先回覆，更快回應"
        case .premiumBenefitRoles: return "可切換更多陪伴角色"
        case .premiumMonthly: return "月付"
        case .premiumYearly: return "年付（省更多）"
        case .premiumPerMonth: return "約 %@/月"
        case .premiumSubscribe: return "訂閱"
        case .premiumSyncing: return "同步中..."
        case .restorePurchases: return "恢復購買"
        case .restoreSuccess: return "已恢復 Premium"
        case .restoreNoPurchase: return "找不到可恢復的購買記錄"
        case .restoreNoPurchaseHint: return "您尚未購買 Premium，請點擊上方「訂閱」按鈕完成購買"
        case .premiumProductsLoadHint: return "若未看到訂閱方案，請先點擊下方「重試載入」。若出現「Sign in with Apple Account」視窗，請點「OK」完成模擬登入"
        case .premiumRetryLoad: return "重試載入"
        case .termsOfService: return "服務條款"
        case .subscriptionTerms: return "訂閱將自動續期，可隨時在 App Store 設定中取消"
        case .premiumAlreadySubscribed: return "你已是 Premium 會員"
        case .manageSubscription: return "管理訂閱"
        case .premiumExpiresOn: return "到期日"
        case .restoreCanceledHint: return "若您已取消訂閱，訂閱將於到期日後失效，屆時無法恢復。"
            
        // B-026 用量限制
        case .usageLimitTitle: return "今天的陪伴額度用完了"
        case .usageLimitInteractionDesc: return "免費版每篇回憶最多 4 次陪伴互動，升級 Premium 可享不限次陪伴 ✨"
        case .usageLimitSummaryDesc: return "免費版每天可生成 1 次回憶總結，升級 Premium 可不限次生成 ✨"
        case .usageLimitDismiss: return "明天再說"
        case .usageInteractionHint: return "剩餘 %d 次互動"
        case .usageSummaryHint: return "今日總結額度已用完"
            
        // B-027 Premium 優先佇列
        case .premiumPriorityHint: return "優先回覆中…"
            
        // B-020 稳定性
        case .rateLimitMessage: return "操作過於頻繁，請 %d 秒後再試"
        case .loadingMore: return "載入更多..."
        case .noMoreData: return "已載入全部"
        }
    }
    
    /// 英文值
    private var enValue: String {
        switch self {
        // Common
        case .done: return "Done"
        case .cancel: return "Cancel"
        case .confirm: return "OK"
        case .delete: return "Delete"
        case .retry: return "Retry"
        case .retryAll: return "Retry All"
        case .search: return "Search"
        case .clear: return "Clear"
        case .close: return "Close"
        case .save: return "Save"
        case .all: return "All"
        case .processing: return "Processing..."
        case .loading: return "Loading..."
        case .error: return "Error"
        case .hint: return "Notice"
        case .unknownError: return "An unknown error occurred"
            
        // Home
        case .memory: return "InnerBloom"
        case .searchDiary: return "Search diary..."
        case .noDiaryYet: return "No diary entries yet"
        case .swipeLeftToCreate: return "Swipe left to create your first entry"
        case .noDiaryInCategory: return "No entries in this category"
        case .searchResult: return "Search Results"
        case .foundDiaries: return "Found %d entries"
            
        // Sync status
        case .syncFailed: return "Sync Failed"
        case .syncFailedCount: return "%d entries failed to sync"
        case .savedLocallyRetryLater: return "Saved locally, tap to retry"
            
        // Creating mode
        case .conversation: return "Chat"
        case .saveMemory: return "Save Memory"
        case .generatingTitle: return "Generating title..."
        case .generatingSummary: return "Writing your diary..."
        case .aiGenerating: return "Writing your diary..."
        case .uploading: return "Uploading..."
        case .saving: return "Saving..."
        case .noContent: return "No content"
            
        // Media area
        case .tapToUpload: return "Tap to Upload"
            
        // Input area
        case .listening: return "Listening..."
        case .shareYourMood: return "Share your mood..."
        case .stopRecording: return "Stop recording"
        case .startVoiceInput: return "Start voice input"
        case .tapToStopRecording: return "Tap to stop recording and transcribe"
        case .tapToStartVoice: return "Tap to start voice input"
        case .notSureWhatToSay: return "Not sure what to say? Try these:"
        case .moreMessages: return "%d more messages"
            
        // Media selection
        case .selectPhotoOrVideo: return "Select Photo/Video"
        case .cannotReadPhoto: return "Cannot read photo"
        case .cannotReadVideo: return "Cannot read video"
        case .cannotGeneratePreview: return "Cannot generate video preview"
        case .photoReadFailed: return "Failed to read photo: "
        case .videoReadFailed: return "Failed to read video: "
            
        // Chat
        case .reply: return "Reply..."
        case .reviewConversation: return "Review Conversation"
        case .conversationRecords: return "%d messages"
        case .aiGeneratedTags: return "Auto Generated Tags"
        case .aiViewOfImage: return "What's in the Photo"
            
        // Diary detail
        case .deleteDiary: return "Delete Diary"
        case .mediaCannotPlay: return "Media cannot be played"
            
        // Settings
        case .settings: return "Settings"
        case .appearance: return "Appearance"
        case .darkMode: return "Dark Mode"
        case .lightMode: return "Light Mode"
        case .companionRole: return "Companion Role"
        case .companionRoleLockedHint: return "Upgrade to Premium to switch companion roles"
        case .roleNameWarm: return "Nuan"
        case .roleNameMinimal: return "Heng"
        case .roleNameHumorous: return "Le"
        case .roleNameEmpathetic: return "Cheng"
        case .roleTagWarm: return "Caring Friend"
        case .roleTagMinimal: return "Rational Colleague"
        case .roleTagHumorous: return "Fun Buddy"
        case .roleTagEmpathetic: return "One Who Gets You"
        case .roleExampleWarm: return "You've had a long day. Want to tell me what happened?"
        case .roleExampleMinimal: return "1. What happened 2. How you feel 3. Next steps"
        case .roleExampleHumorous: return "That's hilarious! So what happened next?"
        case .roleExampleEmpathetic: return "I get it. Can you tell me more about what made you feel that way?"
        case .aiAssistant: return "Companion"
        case .aiToneStyle: return "Companion Role"
        case .autoGenerateTitle: return "Auto Generate Title"
        case .autoGenerateTitleDesc: return "Automatically generate diary title when saving"
        case .autoGenerateTags: return "Auto Generate Tags"
        case .autoGenerateTagsDesc: return "Automatically generate diary tags when saving"
        case .language: return "Language"
        case .languageChangeNote: return "Changes take effect immediately"
        case .privacy: return "Privacy"
        case .allowLocationSharing: return "Allow Location Sharing"
        case .allowLocationSharingDesc: return "Use your location for a more personalized experience"
        case .privacyPolicy: return "Privacy Policy"
        case .about: return "About"
        case .version: return "Version"
        case .buildNumber: return "Build"
        case .resetAllSettings: return "Reset All Settings"
        case .developer: return "Developer"
        case .showModelInfo: return "Show Model Info"
        case .showModelInfoDesc: return "Display model provider in diary details"
        case .currentModel: return "Current Model"
        case .cloudService: return "Cloud Service"
        case .connected: return "Connected"
        case .notConfigured: return "Not Configured"
            
        // AI Tone Style
        case .toneWarm: return "Warm & Healing"
        case .toneWarmDesc: return "Like a good friend, offering warm companionship"
        case .toneMinimal: return "Minimal & Objective"
        case .toneMinimalDesc: return "Concise and objective, focusing on facts"
        case .toneHumorous: return "Humorous & Fun"
        case .toneHumorousDesc: return "Light and fun, making journaling enjoyable"
        case .toneEmpathetic: return "Empathetic"
        case .toneEmpatheticDesc: return "Deep understanding of your feelings"
            
        // Greetings & Welcome
        case .greetingEarlyMorning: return "It's late, still awake? "
        case .greetingMorning: return "Good morning! A new day begins~ "
        case .greetingNoon: return "Good afternoon! Had lunch yet? "
        case .greetingAfternoon: return "Good afternoon! "
        case .greetingEvening: return "Good evening! "
        case .greetingNight: return "Good evening! "
            
        case .welcomePhotoInstant: return "%@This photo looks like it has a story! Want to share what was happening when you took it?"
        case .welcomeVideoInstant: return "%@What special moment does this video capture? I'd love to hear about it~"
        case .welcomePhotoDefault: return "This photo seems to have a story. Can you tell me about it?"
        case .welcomeVideoDefault: return "What special moment does this video capture?"
            
        case .openerJoyfulPhoto: return "I can feel the joyful vibe in this photo! Want to share more about it?"
        case .openerJoyfulVideo: return "I can feel the joyful vibe in this video! Want to share more about it?"
        case .openerPeacefulPhoto: return "This photo gives such a peaceful feeling. What made you want to capture this moment?"
        case .openerPeacefulVideo: return "This video gives such a peaceful feeling. What made you want to capture this moment?"
        case .openerNostalgicPhoto: return "This photo seems to hold many stories. Would you like to chat about it?"
        case .openerNostalgicVideo: return "This video seems to hold many stories. Would you like to chat about it?"
        case .openerAdventurous: return "Looks like an amazing experience! Can you tell me what happened?"
        case .openerTagTravel: return "Is this scenery from a trip? It looks beautiful. Can you tell me about the journey?"
        case .openerTagFriends: return "Time with friends is always special. What was the occasion?"
        case .openerTagFood: return "That looks delicious! Where did you enjoy it?"
        case .openerDefaultPhoto: return "This photo has a great feel to it. Can you tell me the story behind it?"
        case .openerDefaultVideo: return "What special moment does this video capture? I'd love to hear about it."
            
        // Login/Logout (B-018)
        case .login: return "Login"
        case .logout: return "Logout"
        case .signUp: return "Sign Up"
        case .signIn: return "Sign In"
        case .email: return "Email"
        case .password: return "Password"
        case .verificationCode: return "Verification Code"
        case .sendVerificationCode: return "Send Code"
        case .verifyAndLogin: return "Verify & Login"
        case .loginWithPassword: return "Login with Password"
        case .loginWithOTP: return "Login with Code"
        case .enterEmail: return "Enter your email"
        case .enterPassword: return "Enter password"
        case .enterVerificationCode: return "Enter verification code"
        case .codeSent: return "Code Sent"
        case .codeSentDesc: return "A verification code has been sent to %@"
        case .loginWelcome: return "Welcome to InnerBloom"
        case .loginSubtitle: return "Record your life, chat with your companion"
        case .loginPrivacyHint: return ""
        case .loggingIn: return "Signing in..."
        case .signingUp: return "Signing up..."
        case .sendingCode: return "Sending..."
        case .verifying: return "Verifying..."
        case .logoutConfirm: return "Sign out?"
        case .logoutConfirmDesc: return "Local cache will be cleared, but your diary data is safely stored in the cloud"
        case .account: return "Account"
        case .currentAccount: return "Current Account"
        case .notLoggedIn: return "Not Logged In"
        case .loginExpired: return "Session Expired"
        case .loginExpiredDesc: return "Please sign in again to continue"
        case .noAccount: return "Don't have an account?"
        case .haveAccount: return "Already have an account?"
        case .passwordMinLength: return "Password must be at least 6 characters"
        case .orContinueWith: return "Or continue with"
        case .otpExpired: return "Verification code has expired, please resend"
        case .signUpSuccess: return "Sign Up Successful"
        case .signUpSuccessDesc: return "Account created, please sign in"
        case .userAlreadyRegistered: return "This email is already registered, please sign in"
            
        // Privacy Policy
        case .privacyPolicyTitle: return "Privacy Policy"
        case .dataCollection: return "Data Collection"
        case .dataCollectionContent: return "• We collect photos and videos you upload for analysis and diary generation\n• We collect your conversation content for diary summaries\n• We collect location information (with your permission) for a more personalized experience"
        case .dataUsage: return "Data Usage"
        case .dataUsageContent: return "• Your media content is only used for diary generation and companion conversations\n• Your data is securely stored in the cloud (Supabase)\n• We will not sell your personal data to third parties"
        case .dataSecurity: return "Data Security"
        case .dataSecurityContent: return "• All data transfers use HTTPS encryption\n• Media files are stored in secure cloud storage\n• You can delete your diaries and data at any time"
        case .yourRights: return "Your Rights"
        case .yourRightsContent: return "• You can disable media analysis and location sharing in Settings\n• You can delete your diaries and related data at any time\n• You can contact us to export or delete all your data"
        case .lastUpdated: return "Last Updated: December 2024"
            
        // B-022/B-023 Premium
        case .upgradePremium: return "Upgrade Premium"
        case .premium: return "Premium"
        case .premiumTitle: return "Unlock Full Companion Experience"
        case .premiumSubtitle: return "Unlimited chat & summary, priority replies, more companion roles"
        case .premiumBenefits: return "Premium Benefits"
        case .premiumBenefitUnlimitedChat: return "Unlimited companion chat"
        case .premiumBenefitUnlimitedSummary: return "Unlimited daily summaries"
        case .premiumBenefitPriority: return "Priority replies, faster response"
        case .premiumBenefitRoles: return "Switch between more companion roles"
        case .premiumMonthly: return "Monthly"
        case .premiumYearly: return "Yearly (Save more)"
        case .premiumPerMonth: return "~%@/month"
        case .premiumSubscribe: return "Subscribe"
        case .premiumSyncing: return "Syncing..."
        case .restorePurchases: return "Restore Purchases"
        case .restoreSuccess: return "Premium Restored"
        case .restoreNoPurchase: return "No purchases to restore"
        case .restoreNoPurchaseHint: return "You haven't purchased Premium yet. Please tap Subscribe above to purchase"
        case .premiumProductsLoadHint: return "If you don't see plans, tap Retry below. When \"Sign in with Apple Account\" appears, tap OK to simulate sign-in"
        case .premiumRetryLoad: return "Retry Load"
        case .termsOfService: return "Terms of Service"
        case .subscriptionTerms: return "Subscription auto-renews. Cancel anytime in App Store settings"
        case .premiumAlreadySubscribed: return "You are already a Premium member"
        case .manageSubscription: return "Manage Subscription"
        case .premiumExpiresOn: return "Expires"
        case .restoreCanceledHint: return "If you canceled, your subscription will end after the expiry date and cannot be restored."
            
        // B-026 用量限制
        case .usageLimitTitle: return "Today's companion sessions are used up"
        case .usageLimitInteractionDesc: return "Free plan allows up to 4 companion interactions per memory. Upgrade to Premium for unlimited access ✨"
        case .usageLimitSummaryDesc: return "Free plan allows 1 memory summary per day. Upgrade to Premium for unlimited summaries ✨"
        case .usageLimitDismiss: return "Maybe tomorrow"
        case .usageInteractionHint: return "%d interactions left"
        case .usageSummaryHint: return "Daily summary limit reached"
            
        // B-027 Premium 優先佇列
        case .premiumPriorityHint: return "Priority response..."
            
        // B-020 稳定性
        case .rateLimitMessage: return "Too many requests, please try again in %d seconds"
        case .loadingMore: return "Loading more..."
        case .noMoreData: return "All loaded"
        }
    }
}

// MARK: - 便捷扩展

extension String {
    /// 快速获取本地化字符串
    static func localized(_ key: L10nKey) -> String {
        return LocalizationManager.shared.localized(key)
    }
    
    /// 快速获取带参数的本地化字符串
    static func localized(_ key: L10nKey, args: CVarArg...) -> String {
        let format = LocalizationManager.shared.localized(key)
        return String(format: format, arguments: args)
    }
}

// MARK: - SwiftUI View 扩展

extension View {
    /// 监听语言变化，强制刷新视图
    func observeLanguageChange() -> some View {
        let _ = LocalizationManager.shared.languageChangeId
        return self
    }
}
