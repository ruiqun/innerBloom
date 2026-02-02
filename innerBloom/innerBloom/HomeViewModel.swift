//
//  HomeViewModel.swift
//  innerBloom
//
//  主页视图模型 - 管理 S-001 的状态与逻辑
//  B-003: 整合媒体选择与本机草稿保存
//  B-004: 整合 Supabase Storage 云端上传
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
        isSavingMedia = false
        isSavingDraft = false
        errorMessage = nil
    }
    
    /// 结束保存 (F-005, B-004)
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
        draft.touch()
        
        // 保存草稿到本机
        do {
            try draftManager.saveDraft(draft)
            print("[HomeViewModel] Draft saved locally")
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
    
    // MARK: - 聊天逻辑 (F-004, B-007)
    
    /// 发送用户消息
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMsg = ChatMessage(sender: .user, content: text)
        chatMessages.append(userMsg)
        print("[HomeViewModel] User sent message: \(text)")
        
        // 更新草稿并保存到本机 (D-003)
        updateDraftMessages()
        
        // 模拟 AI 回复（带打字指示器）
        simulateAITypingAndResponse(text: text)
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
    
    /// 模拟 AI 打字和回复 (B-007)
    private func simulateAITypingAndResponse(text: String) {
        // 1. 显示打字指示器
        isAITyping = true
        
        // 2. 根据用户输入生成智能回复（假数据）
        let response = generateAIResponse(for: text)
        
        // 3. 模拟打字延迟（根据回复长度动态调整）
        let typingDuration = min(Double(response.count) * 0.03 + 0.8, 3.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) { [weak self] in
            guard let self = self else { return }
            
            // 隐藏打字指示器
            self.isAITyping = false
            
            // 添加 AI 消息
            let aiMsg = ChatMessage(sender: .ai, content: response)
            self.chatMessages.append(aiMsg)
            
            // 保存到本机
            self.updateDraftMessages()
            
            print("[HomeViewModel] AI sent message: \(response)")
        }
    }
    
    /// 生成 AI 回复（假数据，B-007）
    private func generateAIResponse(for userInput: String) -> String {
        let input = userInput.lowercased()
        
        // 根据用户输入内容匹配合适的回复
        if input.contains("开心") || input.contains("高兴") || input.contains("快乐") {
            return [
                "看得出来你很开心呢！是什么让你这么高兴？",
                "能感受到你的喜悦，这种快乐的时刻值得记录下来。",
                "真好！快乐是会传染的，我也感到开心了。"
            ].randomElement()!
        }
        
        if input.contains("难过") || input.contains("伤心") || input.contains("哭") {
            return [
                "听起来你现在不太好受，想聊聊发生了什么吗？",
                "没关系，有时候需要让情绪流出来。我在这里陪着你。",
                "这种感觉一定很不好受，但请相信这会过去的。"
            ].randomElement()!
        }
        
        if input.contains("累") || input.contains("疲") || input.contains("辛苦") {
            return [
                "辛苦了，给自己一点休息的时间吧。",
                "能感受到你的疲惫，有时候放慢脚步也很重要。",
                "听起来你需要好好休息一下，要对自己好一点。"
            ].randomElement()!
        }
        
        if input.contains("旅行") || input.contains("出去") || input.contains("玩") {
            return [
                "听起来是很棒的经历！最让你印象深刻的是什么？",
                "旅行总是能带来不一样的心情，这次有什么特别的收获吗？",
                "好想听你多说说这次的见闻！"
            ].randomElement()!
        }
        
        if input.contains("朋友") || input.contains("家人") || input.contains("他") || input.contains("她") {
            return [
                "和重要的人在一起的时光总是特别珍贵呢。",
                "听起来你们的关系很好，能多说说吗？",
                "这样的回忆一定会成为美好的记忆。"
            ].randomElement()!
        }
        
        if input.contains("工作") || input.contains("上班") || input.contains("加班") {
            return [
                "工作之余也要记得照顾好自己。",
                "辛苦了！工作固然重要，但你的健康更重要。",
                "听起来工作挺忙的，有什么想分享的吗？"
            ].randomElement()!
        }
        
        // 默认回复池
        return ChatMessage.aiResponses.randomElement() ?? "我明白了，这真的很特别。"
    }
    
    /// 触发首次 AI 分析回应 (B-007)
    private func triggerInitialAIResponse(for mediaType: MediaType) {
        isAITyping = true
        
        // 延迟显示欢迎消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            self.isAITyping = false
            
            let welcomeMsg = ChatMessage.welcomeMessage(for: mediaType)
            self.chatMessages.append(welcomeMsg)
            self.updateDraftMessages()
            
            print("[HomeViewModel] AI welcome message sent")
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
