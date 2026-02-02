//
//  HomeViewModel.swift
//  innerBloom
//
//  主页视图模型 - 管理 S-001 的状态与逻辑
//  B-003: 整合媒体选择与本机草稿保存
//  B-004: 整合 Supabase Storage 云端上传
//  B-008: 接入 AI 分析（F-003）
//  B-009: 接入 AI 连续聊天（F-004）
//

import Foundation
import SwiftUI

/// 主页显示模式
enum HomeMode {
    case browsing   // 浏览模式：查看日记列表
    case creating   // 创建模式：新增日记 + 聊天
}

/// 媒体选择结果
struct MediaSelection {
    let image: UIImage?      // 图片（照片或视频缩略图）
    let videoData: Data?     // 视频数据（仅视频时有值）
    let mediaType: MediaType
}

/// 主页视图模型
/// 使用 @Observable 宏（遵循 .cursorrules）
@Observable
final class HomeViewModel {
    
    // MARK: - 显示模式
    
    /// 当前模式（浏览/创建）
    var currentMode: HomeMode = .browsing
    
    // MARK: - 标签相关 (F-009)
    
    /// 所有可用标签
    var availableTags: [Tag] = [Tag.all]
    
    /// 当前选中的标签
    var selectedTag: Tag = Tag.all
    
    // MARK: - 日记列表 (F-006)
    
    /// 当前标签下的日记列表
    var diaryEntries: [DiaryEntry] = []
    
    /// 是否正在加载
    var isLoading: Bool = false
    
    // MARK: - 创建模式相关
    
    /// 当前正在创建的日记（草稿）
    var currentDraft: DiaryEntry?
    
    /// 选中的媒体图片（临时存储，用于显示）
    var selectedMediaImage: UIImage?
    
    /// 选中的视频数据（临时存储）
    var selectedVideoData: Data?
    
    /// 当前媒体类型
    var currentMediaType: MediaType = .photo
    
    /// 用户输入的文字
    var userInputText: String = ""
    
    /// 是否正在录音
    var isRecording: Bool = false
    
    /// 当前会话的聊天消息 (D-003)
    var chatMessages: [ChatMessage] = []
    
    /// AI 是否正在输入 (B-007)
    var isAITyping: Bool = false
    
    /// 是否显示完整聊天视图 (B-007)
    var showFullChatView: Bool = false
    
    // MARK: - AI 分析相关 (B-008)
    
    /// 是否正在进行 AI 分析
    var isAnalyzing: Bool = false
    
    /// 当前媒体的 AI 分析结果 (D-004)
    var currentAnalysis: AIAnalysisResult?
    
    /// AI 分析进度文字
    var analysisProgressText: String = ""
    
    // MARK: - 状态标识
    
    /// 是否正在保存媒体
    var isSavingMedia: Bool = false
    
    /// 是否正在保存草稿
    var isSavingDraft: Bool = false
    
    /// 是否正在上传到云端 (B-004)
    var isUploading: Bool = false
    
    /// 上传进度描述 (B-004)
    var uploadProgressText: String = ""
    
    /// 错误消息
    var errorMessage: String?
    
    /// 是否显示错误提示
    var showError: Bool = false
    
    // MARK: - 管理器
    
    private let mediaManager = LocalMediaManager.shared
    private let draftManager = LocalDraftManager.shared
    private let storageService = SupabaseStorageService.shared  // B-004
    private let databaseService = SupabaseDatabaseService.shared // B-005
    private let networkMonitor = NetworkMonitor.shared          // B-004
    private let aiService = AIService.shared                    // B-008
    
    // MARK: - 初始化
    
    init() {
        print("[HomeViewModel] Initialized")
        // 初始加载标签
        loadTags()
        // 加载日记列表
        loadDiariesForCurrentTag()
        // 加载未完成的草稿（如有）
        loadPendingDrafts()
    }
    
    // MARK: - 标签操作 (B-005)
    
    /// 加载标签列表
    func loadTags() {
        print("[HomeViewModel] Loading tags...")
        
        // 先使用本地预设
        availableTags = [Tag.all]
        selectedTag = Tag.all
        
        // 异步从云端加载
        Task {
            await loadTagsFromCloud()
        }
    }
    
    /// 从云端加载标签
    @MainActor
    private func loadTagsFromCloud() async {
        guard networkMonitor.isConnected else {
            print("[HomeViewModel] Offline, using local tags")
            return
        }
        
        do {
            let cloudTags = try await databaseService.getTags()
            if !cloudTags.isEmpty {
                availableTags = cloudTags
                // 确保选中的标签仍然有效
                if !availableTags.contains(where: { $0.id == selectedTag.id }) {
                    selectedTag = availableTags.first ?? Tag.all
                }
                print("[HomeViewModel] Tags loaded from cloud: \(cloudTags.count)")
            }
        } catch {
            print("[HomeViewModel] Failed to load tags from cloud: \(error)")
        }
    }
    
    /// 选择标签
    func selectTag(_ tag: Tag) {
        print("[HomeViewModel] Selected tag: \(tag.name)")
        selectedTag = tag
        loadDiariesForCurrentTag()
    }
    
    // MARK: - 日记列表操作 (B-005)
    
    /// 加载当前标签下的日记
    func loadDiariesForCurrentTag() {
        print("[HomeViewModel] Loading diaries for tag: \(selectedTag.name)")
        isLoading = true
        
        Task {
            await loadDiariesFromCloud()
        }
    }
    
    /// 从云端加载日记
    @MainActor
    private func loadDiariesFromCloud() async {
        defer { isLoading = false }
        
        guard networkMonitor.isConnected else {
            print("[HomeViewModel] Offline, cannot load diaries")
            diaryEntries = []
            return
        }
        
        do {
            // 如果选中「全部」标签，传 nil；否则传标签 ID
            let tagId = selectedTag.id.uuidString == "00000000-0000-0000-0000-000000000000" ? nil : selectedTag.id
            let entries = try await databaseService.getDiaries(tagId: tagId)
            diaryEntries = entries
            print("[HomeViewModel] Diaries loaded from cloud: \(entries.count)")
        } catch {
            print("[HomeViewModel] Failed to load diaries: \(error)")
            diaryEntries = []
        }
    }
    
    /// 加载未完成的草稿
    private func loadPendingDrafts() {
        let drafts = draftManager.loadAllDrafts()
        if !drafts.isEmpty {
            print("[HomeViewModel] Found \(drafts.count) pending drafts")
            // TODO: 可以提示用户有未完成的草稿
        }
    }
    
    // MARK: - 模式切换 (F-010)
    
    /// 切换到创建模式（右→左滑触发）
    func enterCreatingMode() {
        print("[HomeViewModel] Entering creating mode")
        currentMode = .creating
        // 重置状态
        resetCreatingState()
    }
    
    /// 取消创建，返回浏览模式
    func cancelCreating() {
        print("[HomeViewModel] Canceling creation, back to browsing")
        
        // 如果有草稿且已选择媒体，提示用户是否保存
        if currentDraft != nil && selectedMediaImage != nil {
            // 自动保存草稿
            saveDraftAsync()
        }
        
        currentMode = .browsing
        resetCreatingState()
    }
    
    /// 重置创建状态
    private func resetCreatingState() {
        currentDraft = nil
        selectedMediaImage = nil
        selectedVideoData = nil
        currentMediaType = .photo
        userInputText = ""
        chatMessages = []
        isAITyping = false          // B-007
        showFullChatView = false    // B-007
        isAnalyzing = false         // B-008
        currentAnalysis = nil       // B-008
        analysisProgressText = ""   // B-008
        isSendingMessage = false    // B-009
        pendingRetryMessage = nil   // B-009
        isSavingMedia = false
        isSavingDraft = false
        errorMessage = nil
    }
    
    /// 结束保存 (F-005, B-004, B-008)
    func finishAndSave() {
        print("[HomeViewModel] Finish and save triggered")
        
        guard var draft = currentDraft else {
            showErrorMessage("没有可保存的内容")
            return
        }
        
        // 更新草稿数据
        draft.userInputText = userInputText.isEmpty ? nil : userInputText
        draft.messages = chatMessages
        draft.isSaved = true
        
        // B-008: 保存 AI 分析结果
        if let analysis = currentAnalysis {
            draft.aiAnalysisResult = analysis.description
            draft.isAnalyzed = true
        }
        
        draft.touch()
        
        // 保存草稿到本机
        do {
            try draftManager.saveDraft(draft)
            print("[HomeViewModel] Draft saved locally (with analysis: \(draft.isAnalyzed))")
        } catch {
            showErrorMessage("保存失败：\(error.localizedDescription)")
            return
        }
        
        // 更新当前草稿引用
        currentDraft = draft
        
        // 异步上传到云端 (B-004)
        Task {
            await uploadToCloud()
        }
    }
    
    // MARK: - 云端上传 (B-004, B-005)
    
    /// 上传媒体到 Supabase Storage 并保存到数据库
    @MainActor
    private func uploadToCloud() async {
        guard var draft = currentDraft else { return }
        
        // 检查网络状态
        guard networkMonitor.isConnected else {
            print("[HomeViewModel] Offline, skipping cloud upload")
            draft.markSyncFailed("无网络连接，已保存到本机")
            saveDraftQuietly(draft)
            finishSaveFlow()
            return
        }
        
        // 检查 Supabase 配置
        guard SupabaseConfig.shared.isConfigured else {
            print("[HomeViewModel] Supabase not configured, skipping upload")
            draft.markSyncFailed("云端服务未配置")
            saveDraftQuietly(draft)
            finishSaveFlow()
            return
        }
        
        // 开始上传
        isUploading = true
        uploadProgressText = "正在上传媒体..."
        draft.markSyncing()
        saveDraftQuietly(draft)
        
        var uploadSuccess = true
        
        // 1. 上传媒体和缩略图到 Storage
        let result = await storageService.uploadMediaWithThumbnail(
            localMediaPath: draft.localMediaPath ?? "",
            localThumbnailPath: draft.thumbnailPath,
            diaryId: draft.id,
            mediaType: draft.mediaType
        )
        
        // 处理上传结果
        if let mediaResult = result.mediaResult {
            draft.updateCloudMedia(path: mediaResult.path, url: mediaResult.publicURL)
            print("[HomeViewModel] Media uploaded: \(mediaResult.path)")
        } else if !result.errors.isEmpty {
            uploadSuccess = false
        }
        
        if let thumbResult = result.thumbnailResult {
            draft.updateCloudThumbnail(path: thumbResult.path, url: thumbResult.publicURL)
            print("[HomeViewModel] Thumbnail uploaded: \(thumbResult.path)")
        }
        
        // 2. 保存日记到数据库 (B-005)
        uploadProgressText = "正在保存日记..."
        
        do {
            let savedDiary = try await databaseService.upsertDiary(draft)
            draft = savedDiary
            print("[HomeViewModel] Diary saved to database")
            
            // 3. 保存聊天消息到数据库
            if !draft.messages.isEmpty {
                uploadProgressText = "正在保存消息..."
                try await databaseService.saveMessages(draft.messages, for: draft.id)
                print("[HomeViewModel] Messages saved to database")
            }
            
            // 4. 保存标签关联（如果有标签）
            if !draft.tagIds.isEmpty {
                try await databaseService.saveDiaryTags(diaryId: draft.id, tagIds: draft.tagIds)
                print("[HomeViewModel] Tags saved to database")
            }
            
        } catch {
            print("[HomeViewModel] Failed to save to database: \(error)")
            uploadSuccess = false
        }
        
        // 更新同步状态
        if uploadSuccess {
            draft.markSynced()
            uploadProgressText = "保存完成"
            print("[HomeViewModel] Cloud sync completed")
        } else {
            let errorMsg = result.errors.first?.localizedDescription ?? "保存失败"
            draft.markSyncFailed(errorMsg)
            uploadProgressText = "部分保存失败"
            print("[HomeViewModel] Cloud sync partial failure: \(errorMsg)")
        }
        
        // 保存最终状态到本机
        saveDraftQuietly(draft)
        
        // 完成保存流程
        finishSaveFlow()
    }
    
    /// 静默保存草稿（不显示错误）
    private func saveDraftQuietly(_ draft: DiaryEntry) {
        do {
            try draftManager.saveDraft(draft)
        } catch {
            print("[HomeViewModel] Failed to save draft quietly: \(error)")
        }
    }
    
    /// 完成保存流程，返回浏览模式
    @MainActor
    private func finishSaveFlow() {
        isUploading = false
        uploadProgressText = ""
        
        // TODO: B-010 实现完整的保存逻辑
        // 1. 生成 AI 总结
        // 2. 生成标签
        
        // 切换回浏览模式
        currentMode = .browsing
        resetCreatingState()
        
        // 重新加载日记列表
        loadDiariesForCurrentTag()
        
        print("[HomeViewModel] Save flow completed")
    }
    
    /// 手动重试云端同步
    func retryCloudSync() {
        guard let draft = currentDraft else { return }
        guard draft.syncStatus == .failed else { return }
        
        Task {
            await uploadToCloud()
        }
    }
    
    // MARK: - 媒体选择 (F-001, B-003)
    
    /// 设置选中的媒体（图片）
    func setSelectedMedia(image: UIImage) {
        print("[HomeViewModel] Photo selected")
        
        currentMediaType = .photo
        selectedMediaImage = image
        selectedVideoData = nil
        chatMessages = []
        
        // 异步保存媒体并创建草稿
        Task {
            await saveMediaAndCreateDraft(image: image, videoData: nil, mediaType: .photo)
        }
    }
    
    /// 设置选中的媒体（视频）
    func setSelectedMedia(videoData: Data, thumbnail: UIImage) {
        print("[HomeViewModel] Video selected")
        
        currentMediaType = .video
        selectedMediaImage = thumbnail
        selectedVideoData = videoData
        chatMessages = []
        
        // 异步保存媒体并创建草稿
        Task {
            await saveMediaAndCreateDraft(image: thumbnail, videoData: videoData, mediaType: .video)
        }
    }
    
    /// 保存媒体并创建草稿
    @MainActor
    private func saveMediaAndCreateDraft(image: UIImage, videoData: Data?, mediaType: MediaType) async {
        isSavingMedia = true
        
        // 1. 创建新草稿 ID
        let draftId = UUID()
        
        do {
            // 2. 保存媒体到本机
            let saveResult: MediaSaveResult
            
            if mediaType == .video, let data = videoData {
                saveResult = try await mediaManager.saveVideo(data, for: draftId)
            } else {
                saveResult = try await mediaManager.saveImage(image, for: draftId)
            }
            
            // 3. 创建草稿对象
            let draft = DiaryEntry(
                id: draftId,
                mediaType: saveResult.mediaType,
                localMediaPath: saveResult.localPath,
                thumbnailPath: saveResult.thumbnailPath
            )
            
            // 4. 保存草稿到本机
            try draftManager.saveDraft(draft)
            
            // 5. 更新状态
            currentDraft = draft
            isSavingMedia = false
            
            print("[HomeViewModel] Media saved and draft created: \(draftId)")
            
            // 6. 触发 AI 欢迎消息 (B-007)
            triggerInitialAIResponse(for: mediaType)
            
        } catch {
            isSavingMedia = false
            showErrorMessage(error.localizedDescription)
            print("[HomeViewModel] Failed to save media: \(error)")
        }
    }
    
    /// 异步保存草稿（用于取消时自动保存）
    private func saveDraftAsync() {
        guard var draft = currentDraft else { return }
        
        draft.userInputText = userInputText.isEmpty ? nil : userInputText
        draft.messages = chatMessages
        draft.touch()
        
        Task {
            do {
                try draftManager.saveDraft(draft)
                print("[HomeViewModel] Draft auto-saved")
            } catch {
                print("[HomeViewModel] Failed to auto-save draft: \(error)")
            }
        }
    }
    
    // MARK: - 语音输入 (F-011, B-006)
    
    /// 语音识别管理器
    private let speechRecognizer = SpeechRecognizer.shared
    
    /// 实时转写文字（录音过程中显示）
    var transcribingText: String = ""
    
    /// 语音识别错误消息
    var speechErrorMessage: String?
    
    /// 开始录音
    func startRecording() {
        print("[HomeViewModel] Start recording")
        
        Task { @MainActor in
            // 清除之前的错误
            speechErrorMessage = nil
            transcribingText = ""
            
            await speechRecognizer.startRecording(
                onUpdate: { [weak self] text in
                    // 实时更新转写文字
                    self?.transcribingText = text
                    self?.userInputText = text
                },
                onComplete: { [weak self] finalText in
                    // 识别完成，更新输入框
                    self?.transcribingText = ""
                    self?.userInputText = finalText
                    print("[HomeViewModel] Speech recognition completed: \(finalText)")
                },
                onError: { [weak self] error in
                    // 处理错误
                    self?.speechErrorMessage = error.localizedDescription
                    self?.showErrorMessage(error.localizedDescription)
                    print("[HomeViewModel] Speech recognition error: \(error)")
                }
            )
            
            isRecording = speechRecognizer.isRecording
        }
    }
    
    /// 停止录音
    func stopRecording() {
        print("[HomeViewModel] Stop recording")
        
        speechRecognizer.stopRecording()
        isRecording = false
        transcribingText = ""
    }
    
    /// 取消录音
    func cancelRecording() {
        print("[HomeViewModel] Cancel recording")
        
        speechRecognizer.cancelRecording()
        isRecording = false
        transcribingText = ""
    }
    
    /// 获取当前音频电平（用于波形动画）
    var audioLevel: Float {
        return speechRecognizer.audioLevel
    }
    
    // MARK: - 聊天逻辑 (F-004, B-007, B-009)
    
    /// 待重试的消息 (F-004 出错处理)
    var pendingRetryMessage: String?
    
    /// 是否正在发送消息
    var isSendingMessage: Bool = false
    
    /// 发送用户消息 (B-009: 真正的 AI 聊天)
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isSendingMessage else {
            print("[HomeViewModel] Already sending message, ignoring")
            return
        }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 添加用户消息到列表
        let userMsg = ChatMessage(sender: .user, content: trimmedText)
        chatMessages.append(userMsg)
        print("[HomeViewModel] User sent message: \(trimmedText)")
        
        // 更新草稿并保存到本机 (D-003)
        updateDraftMessages()
        
        // 调用 AI 服务获取回复 (B-009)
        Task { @MainActor in
            await sendToAIService(userMessage: trimmedText)
        }
    }
    
    /// 发送消息到 AI 服务 (B-009)
    @MainActor
    private func sendToAIService(userMessage: String) async {
        guard let draft = currentDraft else {
            showErrorMessage("请先选择媒体")
            return
        }
        
        isSendingMessage = true
        isAITyping = true
        pendingRetryMessage = nil
        
        do {
            // 调用 AI 服务
            let response = try await aiService.chat(
                messages: chatMessages,
                analysisContext: currentAnalysis,
                diaryId: draft.id
            )
            
            // 添加 AI 回复
            let aiMsg = ChatMessage(sender: .ai, content: response)
            chatMessages.append(aiMsg)
            
            // 保存到本机
            updateDraftMessages()
            
            print("[HomeViewModel] AI response received: \(response.prefix(50))...")
            
        } catch {
            print("[HomeViewModel] AI chat failed: \(error)")
            
            // 保存待重试消息
            pendingRetryMessage = userMessage
            
            // 显示错误（根据错误类型调整提示）
            if let aiError = error as? AIServiceError {
                switch aiError {
                case .noNetwork:
                    showErrorMessage("无网络连接，请检查网络后点击重试")
                case .timeout:
                    showErrorMessage("请求超时，请点击重试")
                default:
                    showErrorMessage("发送失败：\(aiError.localizedDescription)")
                }
            } else {
                showErrorMessage("发送失败，请稍后重试")
            }
        }
        
        isSendingMessage = false
        isAITyping = false
    }
    
    /// 重试发送消息 (F-004 出错处理)
    func retryLastMessage() {
        guard let message = pendingRetryMessage else {
            print("[HomeViewModel] No pending message to retry")
            return
        }
        
        print("[HomeViewModel] Retrying message: \(message)")
        
        // 移除之前的用户消息（避免重复）
        if let lastUserIndex = chatMessages.lastIndex(where: { $0.sender == .user && $0.content == message }) {
            chatMessages.remove(at: lastUserIndex)
        }
        
        // 重新发送
        sendMessage(message)
    }
    
    /// 更新草稿中的消息并保存到本机 (D-003)
    private func updateDraftMessages() {
        guard var draft = currentDraft else { return }
        draft.messages = chatMessages
        draft.touch()
        currentDraft = draft
        
        // 异步保存到本机草稿 (B-007: D-003 本机存消息)
        Task {
            do {
                try draftManager.saveDraft(draft)
                print("[HomeViewModel] Messages saved to local draft: \(draft.messages.count) messages")
            } catch {
                print("[HomeViewModel] Failed to update draft messages: \(error)")
            }
        }
    }
    
    /// 触发 AI 分析并生成欢迎消息 (B-007, B-008)
    /// F-003: 把媒体内容交给 AI 产生「它看到了什么」的理解
    private func triggerInitialAIResponse(for mediaType: MediaType) {
        guard let image = selectedMediaImage else {
            // 没有媒体图片，使用默认欢迎消息
            sendDefaultWelcomeMessage(for: mediaType)
            return
        }
        
        // 开始 AI 分析
        isAnalyzing = true
        isAITyping = true
        analysisProgressText = "正在分析媒体内容..."
        
        Task { @MainActor in
            await performAIAnalysis(image: image, mediaType: mediaType)
        }
    }
    
    /// 执行 AI 分析 (B-008)
    @MainActor
    private func performAIAnalysis(image: UIImage, mediaType: MediaType) async {
        print("[HomeViewModel] Starting AI analysis for \(mediaType.rawValue)")
        
        do {
            // 调用 AI 服务分析媒体
            let analysis = try await aiService.analyzeImage(
                image,
                mediaType: mediaType,
                userContext: userInputText.isEmpty ? nil : userInputText
            )
            
            // 保存分析结果
            currentAnalysis = analysis
            
            // 更新草稿的分析结果 (D-004)
            if var draft = currentDraft {
                draft.aiAnalysisResult = analysis.description
                draft.isAnalyzed = true
                draft.touch()
                currentDraft = draft
                
                // 保存到本机
                do {
                    try draftManager.saveDraft(draft)
                    print("[HomeViewModel] Analysis result saved to draft")
                } catch {
                    print("[HomeViewModel] Failed to save analysis to draft: \(error)")
                }
            }
            
            // 分析完成，生成基于分析结果的欢迎消息
            isAnalyzing = false
            analysisProgressText = ""
            
            sendAnalysisBasedWelcomeMessage(analysis: analysis, mediaType: mediaType)
            
            print("[HomeViewModel] AI analysis completed: \(analysis.description.prefix(50))...")
            
        } catch {
            // 分析失败，使用默认欢迎消息
            print("[HomeViewModel] AI analysis failed: \(error)")
            
            isAnalyzing = false
            analysisProgressText = ""
            
            // 记录错误到草稿
            if var draft = currentDraft {
                draft.lastErrorMessage = "AI 分析失败：\(error.localizedDescription)"
                currentDraft = draft
            }
            
            // 发送默认欢迎消息（降级处理）
            sendDefaultWelcomeMessage(for: mediaType, withError: true)
        }
    }
    
    /// 发送基于 AI 分析的欢迎消息 (B-008)
    private func sendAnalysisBasedWelcomeMessage(analysis: AIAnalysisResult, mediaType: MediaType) {
        isAITyping = false
        
        // 优先使用 AI 建议的开场白
        let content: String
        if let opener = analysis.suggestedOpener, !opener.isEmpty {
            content = opener
        } else {
            // 根据分析结果生成开场白
            content = generateOpenerFromAnalysis(analysis, mediaType: mediaType)
        }
        
        let welcomeMsg = ChatMessage(sender: .ai, content: content)
        chatMessages.append(welcomeMsg)
        updateDraftMessages()
        
        print("[HomeViewModel] AI analysis-based welcome message sent")
    }
    
    /// 根据分析结果生成开场白 (B-008)
    private func generateOpenerFromAnalysis(_ analysis: AIAnalysisResult, mediaType: MediaType) -> String {
        // 根据检测到的情绪调整语气
        if let mood = analysis.mood {
            switch mood.lowercased() {
            case "joyful", "happy", "excited":
                return "感受到这张\(mediaType == .photo ? "照片" : "影片")里的快乐氛围了！能跟我分享一下吗？"
            case "peaceful", "calm", "serene":
                return "这\(mediaType == .photo ? "张照片" : "段影片")给人很宁静的感觉，是什么让你想记录这个时刻？"
            case "nostalgic", "melancholy":
                return "这\(mediaType == .photo ? "张照片" : "段影片")似乎有很多故事，愿意跟我聊聊吗？"
            case "adventurous", "exciting":
                return "看起来是一次很棒的经历！能跟我说说发生了什么吗？"
            default:
                break
            }
        }
        
        // 根据场景标签生成
        if let tags = analysis.sceneTags, !tags.isEmpty {
            if tags.contains(where: { $0.contains("旅行") || $0.contains("风景") }) {
                return "这是旅途中的风景吗？看起来很美，能说说这趟旅程吗？"
            }
            if tags.contains(where: { $0.contains("朋友") || $0.contains("聚会") }) {
                return "和朋友在一起的时光总是特别的，这是什么场合呢？"
            }
            if tags.contains(where: { $0.contains("美食") }) {
                return "看起来很好吃的样子！这是在哪里享用的？"
            }
        }
        
        // 默认开场白
        switch mediaType {
        case .photo:
            return "这张照片拍得很有感觉，能跟我说说背后的故事吗？"
        case .video:
            return "这段影片记录了什么特别的时刻呢？我很想听你分享。"
        }
    }
    
    /// 发送默认欢迎消息（当 AI 分析失败或不可用时）(B-008)
    private func sendDefaultWelcomeMessage(for mediaType: MediaType, withError: Bool = false) {
        isAITyping = false
        
        let content = ChatMessage.welcomeMessage(for: mediaType).content
        
        // 如果是因为错误而降级，可以稍微调整语气
        if withError {
            print("[HomeViewModel] Using fallback welcome message due to analysis error")
        }
        
        let welcomeMsg = ChatMessage(sender: .ai, content: content)
        chatMessages.append(welcomeMsg)
        updateDraftMessages()
        
        print("[HomeViewModel] Default welcome message sent")
    }
    
    /// 手动重新进行 AI 分析 (F-003 出错处理)
    func retryAnalysis() {
        guard let image = selectedMediaImage else {
            showErrorMessage("没有可分析的媒体")
            return
        }
        
        print("[HomeViewModel] Retrying AI analysis")
        
        // 清除之前的分析结果
        currentAnalysis = nil
        if var draft = currentDraft {
            draft.isAnalyzed = false
            draft.aiAnalysisResult = nil
            draft.lastErrorMessage = nil
            currentDraft = draft
        }
        
        // 重新开始分析
        isAnalyzing = true
        isAITyping = true
        analysisProgressText = "正在重新分析..."
        
        Task { @MainActor in
            await performAIAnalysis(image: image, mediaType: currentMediaType)
        }
    }
    
    /// 展开/收起完整聊天视图 (B-007)
    func toggleFullChatView() {
        showFullChatView.toggle()
        print("[HomeViewModel] Full chat view: \(showFullChatView)")
    }
    
    // MARK: - 错误处理
    
    /// 显示错误消息
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        print("[HomeViewModel] Error: \(message)")
    }
    
    /// 清除错误
    func clearError() {
        errorMessage = nil
        showError = false
    }
}
