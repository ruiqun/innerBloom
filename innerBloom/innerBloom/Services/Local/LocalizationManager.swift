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
    case allowMediaAnalysis = "allow_media_analysis"
    case allowMediaAnalysisDesc = "allow_media_analysis_desc"
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
        case .memory: return "MEMORY"
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
        case .generatingSummary: return "AI 正在為你生成日記摘要..."
        case .aiGenerating: return "AI 生成中..."
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
        case .aiGeneratedTags: return "AI 生成的標籤"
        case .aiViewOfImage: return "AI 眼中的畫面"
            
        // 日记详情
        case .deleteDiary: return "刪除日記"
        case .mediaCannotPlay: return "媒體無法播放"
            
        // 设定页
        case .settings: return "設定"
        case .appearance: return "外觀"
        case .darkMode: return "深色模式"
        case .lightMode: return "淺色模式"
        case .aiAssistant: return "AI 助手"
        case .aiToneStyle: return "AI 口吻風格"
        case .autoGenerateTitle: return "自動生成標題"
        case .autoGenerateTitleDesc: return "儲存時 AI 自動為日記生成標題"
        case .autoGenerateTags: return "自動生成標籤"
        case .autoGenerateTagsDesc: return "儲存時 AI 自動為日記生成標籤"
        case .language: return "語言"
        case .languageChangeNote: return "切換語言後立即生效"
        case .privacy: return "隱私"
        case .allowMediaAnalysis: return "允許媒體分析"
        case .allowMediaAnalysisDesc: return "AI 可以分析你的照片/影片內容"
        case .allowLocationSharing: return "允許位置分享"
        case .allowLocationSharingDesc: return "AI 可以獲取當前位置以提供更貼心的陪伴"
        case .privacyPolicy: return "隱私政策"
        case .about: return "關於"
        case .version: return "版本"
        case .buildNumber: return "構建號"
        case .resetAllSettings: return "重置所有設定"
        case .developer: return "開發者"
        case .showModelInfo: return "顯示模型資訊"
        case .showModelInfoDesc: return "在日記詳情中顯示 AI 模型供應商"
        case .currentModel: return "當前模型"
        case .cloudService: return "雲端服務"
        case .connected: return "已連接"
        case .notConfigured: return "未配置"
            
        // AI 口吻风格
        case .toneWarm: return "溫暖治癒"
        case .toneWarmDesc: return "像好朋友一樣，給你溫暖的陪伴"
        case .toneMinimal: return "極簡客觀"
        case .toneMinimalDesc: return "簡潔客觀，專注記錄事實"
        case .toneHumorous: return "幽默風趣"
        case .toneHumorousDesc: return "輕鬆有趣，讓記錄充滿快樂"
        case .toneEmpathetic: return "共情理解"
        case .toneEmpatheticDesc: return "深度理解你的感受，給予共鳴"
            
        // 隐私政策
        case .privacyPolicyTitle: return "隱私政策"
        case .dataCollection: return "資料收集"
        case .dataCollectionContent: return "• 我們收集您上傳的照片和影片，用於 AI 分析和日記生成\n• 我們收集您的對話內容，用於生成日記總結\n• 我們收集位置資訊（經您授權），用於提供更貼心的陪伴體驗"
        case .dataUsage: return "資料使用"
        case .dataUsageContent: return "• 您的媒體內容僅用於生成日記和 AI 對話\n• 您的資料會安全儲存在雲端（Supabase）\n• 我們不會將您的個人資料出售給第三方"
        case .dataSecurity: return "資料安全"
        case .dataSecurityContent: return "• 所有資料傳輸使用 HTTPS 加密\n• 媒體檔案儲存在安全的雲端儲存服務中\n• 您可以隨時刪除自己的日記和資料"
        case .yourRights: return "您的權利"
        case .yourRightsContent: return "• 您可以在設定中關閉媒體分析和位置分享\n• 您可以隨時刪除您的日記和相關資料\n• 您可以聯繫我們請求匯出或刪除所有資料"
        case .lastUpdated: return "最後更新：2024年12月"
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
        case .memory: return "MEMORY"
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
        case .generatingSummary: return "AI is generating your diary summary..."
        case .aiGenerating: return "AI Generating..."
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
        case .aiGeneratedTags: return "AI Generated Tags"
        case .aiViewOfImage: return "AI's View"
            
        // Diary detail
        case .deleteDiary: return "Delete Diary"
        case .mediaCannotPlay: return "Media cannot be played"
            
        // Settings
        case .settings: return "Settings"
        case .appearance: return "Appearance"
        case .darkMode: return "Dark Mode"
        case .lightMode: return "Light Mode"
        case .aiAssistant: return "AI Assistant"
        case .aiToneStyle: return "AI Tone Style"
        case .autoGenerateTitle: return "Auto Generate Title"
        case .autoGenerateTitleDesc: return "AI automatically generates diary title when saving"
        case .autoGenerateTags: return "Auto Generate Tags"
        case .autoGenerateTagsDesc: return "AI automatically generates diary tags when saving"
        case .language: return "Language"
        case .languageChangeNote: return "Changes take effect immediately"
        case .privacy: return "Privacy"
        case .allowMediaAnalysis: return "Allow Media Analysis"
        case .allowMediaAnalysisDesc: return "AI can analyze your photos/videos"
        case .allowLocationSharing: return "Allow Location Sharing"
        case .allowLocationSharingDesc: return "AI can access your location for a more personalized experience"
        case .privacyPolicy: return "Privacy Policy"
        case .about: return "About"
        case .version: return "Version"
        case .buildNumber: return "Build"
        case .resetAllSettings: return "Reset All Settings"
        case .developer: return "Developer"
        case .showModelInfo: return "Show Model Info"
        case .showModelInfoDesc: return "Display AI model provider in diary details"
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
            
        // Privacy Policy
        case .privacyPolicyTitle: return "Privacy Policy"
        case .dataCollection: return "Data Collection"
        case .dataCollectionContent: return "• We collect photos and videos you upload for AI analysis and diary generation\n• We collect your conversation content for diary summaries\n• We collect location information (with your permission) for a more personalized experience"
        case .dataUsage: return "Data Usage"
        case .dataUsageContent: return "• Your media content is only used for diary generation and AI conversations\n• Your data is securely stored in the cloud (Supabase)\n• We will not sell your personal data to third parties"
        case .dataSecurity: return "Data Security"
        case .dataSecurityContent: return "• All data transfers use HTTPS encryption\n• Media files are stored in secure cloud storage\n• You can delete your diaries and data at any time"
        case .yourRights: return "Your Rights"
        case .yourRightsContent: return "• You can disable media analysis and location sharing in Settings\n• You can delete your diaries and related data at any time\n• You can contact us to export or delete all your data"
        case .lastUpdated: return "Last Updated: December 2024"
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
