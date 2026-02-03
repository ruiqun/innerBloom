//
//  HomeViewModel.swift
//  innerBloom
//
//  主页视图模型 - 管理 S-001 的状态与逻辑
//  B-003: 整合媒体选择与本机草稿保存
//  B-004: 整合 Supabase Storage 云端上传
//  B-008: 接入 AI 分析（F-003）
//  B-009: 接入 AI 连续聊天（F-004）
//  B-010: 环境感知整合（F-016 + D-012）+ 结束保存 + 总结/标签生成（F-005）
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
    
    // MARK: - Singleton
    
    /// 单例实例（避免 SwiftUI View 重建时重复初始化）
    static let shared = HomeViewModel()
    
    // MARK: - 显示模式
    
    /// 当前模式（浏览/创建）
    var currentMode: HomeMode = .browsing
    
    /// 当前选中的日记（用于详情页展示 S-002）
    var selectedDiary: DiaryEntry?
    
    /// 当前选择的日记风格
    var selectedStyle: DiaryStyle = .warm
    
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
    
    // MARK: - 搜索相关 (B-014, F-008)
    
    /// 搜索关键字
    var searchText: String = ""
    
    /// 是否正在搜索
    var isSearching: Bool = false
    
    /// 搜索结果（nil 表示未搜索，空数组表示无结果）
    var searchResults: [DiaryEntry]? = nil
    
    /// 显示用的日记列表（优先显示搜索结果）
    var displayEntries: [DiaryEntry] {
        if let results = searchResults {
            return results
        }
        return diaryEntries
    }
    
    /// 是否显示搜索结果
    var isShowingSearchResults: Bool {
        searchResults != nil
    }
    
    // MARK: - 同步状态 (B-015, F-012)
    
    /// 获取失败条目数量
    var failedEntriesCount: Int {
        diaryEntries.filter { $0.processingState == .failed || $0.syncStatus == .failed }.count
    }
    
    /// 是否有失败条目
    var hasFailedEntries: Bool {
        failedEntriesCount > 0
    }
    
    /// 重试所有失败的条目
    func retryAllFailedEntries() {
        let failedEntries = diaryEntries.filter { $0.processingState == .failed || $0.syncStatus == .failed }
        print("[HomeViewModel] Retrying \(failedEntries.count) failed entries")
        
        for entry in failedEntries {
            retryCloudSync(for: entry.id)
        }
    }
    
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
    
    /// AI 建议的话题/选项（用户卡住时显示）
    var suggestedPrompts: [String] = []
    
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
    
    // MARK: - AI 生成相关 (F-005, B-010)
    
    /// 是否正在生成总结/标签
    var isGenerating: Bool = false
    
    /// 生成进度文字
    var generationProgressText: String = ""
    
    /// 生成的标签名称（用于关联到 Tag 表）
    var generatedTagNames: [String] = []
    
    // MARK: - 环境感知 (B-010, F-016)
    
    /// 当前环境上下文（D-012）
    var currentEnvironment: EnvironmentContext?
    
    /// 是否正在获取环境信息
    var isLoadingEnvironment: Bool = false
    
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
    private let environmentService = EnvironmentService.shared  // B-010
    private let aiService = AIService.shared                    // B-008
    
    // MARK: - 初始化
    
    private init() {
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
    
    /// 从云端加载标签（B-013：确保「全部」标签始终首位）
    @MainActor
    private func loadTagsFromCloud() async {
        guard networkMonitor.isConnected else {
            print("[HomeViewModel] Offline, using local tags")
            return
        }
        
        do {
            let cloudTags = try await databaseService.getTags()
            
            // B-013: 合并标签列表，确保「全部」始终在首位
            var mergedTags: [Tag] = []
            
            // 1. 添加本地「全部」标签（固定 ID）
            mergedTags.append(Tag.all)
            
            // 2. 添加云端标签（排除重复的「全部」标签）
            let allTagId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
            let otherTags = cloudTags.filter { $0.id != allTagId }
            
            // 3. 按 sortOrder 排序后追加
            let sortedTags = otherTags.sorted { $0.sortOrder < $1.sortOrder }
            mergedTags.append(contentsOf: sortedTags)
            
            availableTags = mergedTags
            
            // 确保选中的标签仍然有效
            if !availableTags.contains(where: { $0.id == selectedTag.id }) {
                selectedTag = Tag.all
            }
            
            print("[HomeViewModel] Tags loaded from cloud: \(mergedTags.count) (including 全部)")
            
        } catch {
            print("[HomeViewModel] Failed to load tags from cloud: \(error)")
            // 保持使用本地「全部」标签
        }
    }
    
    /// 选择标签
    func selectTag(_ tag: Tag) {
        print("[HomeViewModel] Selected tag: \(tag.name)")
        selectedTag = tag
        loadDiariesForCurrentTag()
    }
    
    // MARK: - 详情页操作 (S-002)
    
    /// 进入日记详情
    func showDiaryDetail(_ entry: DiaryEntry) {
        print("[HomeViewModel] Show detail for diary: \(entry.id)")
        selectedDiary = entry
    }
    
    /// 关闭日记详情
    func closeDiaryDetail() {
        print("[HomeViewModel] Close diary detail")
        selectedDiary = nil
    }
    
    /// 从详情页点击标签跳转
    func selectTagFromDetail(_ tag: Tag) {
        print("[HomeViewModel] Jump to tag from detail: \(tag.name)")
        closeDiaryDetail()
        selectTag(tag)
    }
    
    /// 删除日记
    func deleteDiary(_ entry: DiaryEntry) {
        print("[HomeViewModel] Deleting diary: \(entry.id)")
        
        // 1. 立即更新 UI (Optimistic Update)
        // 先关闭详情页，再移除列表项，让用户感觉“秒删”
        if selectedDiary?.id == entry.id {
            closeDiaryDetail()
        }
        
        // 延迟一点点移除列表项，让关闭动画更自然（可选，这里直接移除也可以）
        if let index = diaryEntries.firstIndex(where: { $0.id == entry.id }) {
            diaryEntries.remove(at: index)
        }
        
        // 2. 异步执行后台删除
        Task {
            // 从本地删除
            try? draftManager.deleteDraft(id: entry.id)
            
            // 从云端删除
            if networkMonitor.isConnected && SupabaseConfig.shared.isConfigured {
                do {
                    try await databaseService.deleteDiary(id: entry.id)
                    print("[HomeViewModel] Cloud diary deleted: \(entry.id)")
                } catch {
                    print("[HomeViewModel] Failed to delete cloud diary: \(error)")
                    // 注意：这里如果失败了，UI 已经删除了。
                    // 理想情况下应该有回滚机制或错误提示，但为了体验流畅，
                    // 这里假设删除意图已传达，暂不回滚 UI。
                }
            }
        }
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
    
    /// 刷新当前列表（B-013：支持下拉刷新的 async 版本）
    @MainActor
    func refreshCurrentList() async {
        print("[HomeViewModel] Refreshing list for tag: \(selectedTag.name)")
        isLoading = true
        
        // 清除搜索状态
        clearSearch()
        
        // 同时刷新标签和日记列表
        await loadTagsFromCloud()
        await loadDiariesFromCloud()
    }
    
    // MARK: - 搜索操作 (B-014, F-008)
    
    /// 执行搜索
    func performSearch() {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !keyword.isEmpty else {
            clearSearch()
            return
        }
        
        print("[HomeViewModel] Searching for: \(keyword)")
        isSearching = true
        
        Task {
            await searchDiaries(keyword: keyword)
        }
    }
    
    /// 清除搜索
    func clearSearch() {
        searchText = ""
        searchResults = nil
        isSearching = false
        print("[HomeViewModel] Search cleared")
    }
    
    /// 从云端搜索日记
    @MainActor
    private func searchDiaries(keyword: String) async {
        defer { isSearching = false }
        
        guard networkMonitor.isConnected else {
            print("[HomeViewModel] Offline, cannot search")
            // 离线时从本地列表搜索
            searchResults = diaryEntries.filter { entry in
                matchesKeyword(entry: entry, keyword: keyword)
            }
            return
        }
        
        do {
            // 根据当前选中的标签决定搜索范围
            let tagId = selectedTag.id.uuidString == "00000000-0000-0000-0000-000000000000" ? nil : selectedTag.id
            let results = try await databaseService.searchDiaries(keyword: keyword, tagId: tagId)
            searchResults = results
            print("[HomeViewModel] Search results: \(results.count)")
        } catch {
            print("[HomeViewModel] Search failed: \(error)")
            // 搜索失败时从本地列表搜索
            searchResults = diaryEntries.filter { entry in
                matchesKeyword(entry: entry, keyword: keyword)
            }
        }
    }
    
    /// 本地匹配关键字
    private func matchesKeyword(entry: DiaryEntry, keyword: String) -> Bool {
        let lowercasedKeyword = keyword.lowercased()
        
        // 搜索标题
        if let title = entry.title?.lowercased(), title.contains(lowercasedKeyword) {
            return true
        }
        
        // 搜索总结
        if let summary = entry.diarySummary?.lowercased(), summary.contains(lowercasedKeyword) {
            return true
        }
        
        // 搜索用户输入
        if let input = entry.userInputText?.lowercased(), input.contains(lowercasedKeyword) {
            return true
        }
        
        return false
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
            
            // 先显示日记列表（不阻塞 UI）
            diaryEntries = entries
            print("[HomeViewModel] Diaries loaded from cloud: \(entries.count)")
            
            // 开发模式：后台静默清理旧日记（不阻塞启动）
            if DevConfig.shouldCleanCloud && entries.count > 1 {
                Task.detached(priority: .background) { [weak self] in
                    await self?.cleanOldCloudDiariesInBackground(entries)
                }
            }
        } catch {
            print("[HomeViewModel] Failed to load diaries: \(error)")
            diaryEntries = []
        }
    }
    
    /// 开发模式：后台静默清理云端旧日记（不阻塞 UI）
    private func cleanOldCloudDiariesInBackground(_ entries: [DiaryEntry]) async {
        print("[HomeViewModel] 🛠️ Dev mode: Background cleaning started...")
        
        // 按创建时间排序，最新的在前
        let sortedEntries = entries.sorted { $0.createdAt > $1.createdAt }
        
        guard let newestEntry = sortedEntries.first else {
            return
        }
        
        // 收集需要保留的 tag IDs
        let keepTagIds = Set(newestEntry.tagIds)
        
        // 删除除最新一条外的所有日记
        var deletedCount = 0
        for (index, entry) in sortedEntries.enumerated() {
            if index > 0 {
                do {
                    try await databaseService.deleteDiary(id: entry.id)
                    deletedCount += 1
                    print("[HomeViewModel] 🗑️ Deleted cloud diary: \(entry.id)")
                } catch {
                    print("[HomeViewModel] ⚠️ Failed to delete diary \(entry.id): \(error)")
                }
            }
        }
        
        // 清理未使用的 tags
        await cleanUnusedTagsInBackground(keepTagIds: keepTagIds)
        
        // 标记已清理
        await MainActor.run {
            DevConfig.markCloudCleaned()
        }
        
        print("[HomeViewModel] ✅ Dev mode: Background cleaning completed (\(deletedCount) diaries)")
        
        // 刷新 UI 列表（只保留最新一条）
        await MainActor.run {
            diaryEntries = [newestEntry]
        }
    }
    
    /// 后台清理未使用的 tags
    private func cleanUnusedTagsInBackground(keepTagIds: Set<UUID>) async {
        // 获取所有 tags
        guard let allTags = try? await databaseService.getTags() else { return }
        
        // 需要删除的 tags（不在保留列表中的）
        let tagsToDelete = allTags.filter { tag in
            // 保留「全部」标签
            if tag.id.uuidString == "00000000-0000-0000-0000-000000000000" {
                return false
            }
            // 保留正在使用的 tags
            return !keepTagIds.contains(tag.id)
        }
        
        for tag in tagsToDelete {
            do {
                try await databaseService.deleteTag(id: tag.id)
                print("[HomeViewModel] 🗑️ Deleted unused tag: \(tag.name)")
            } catch {
                print("[HomeViewModel] ⚠️ Failed to delete tag \(tag.name): \(error)")
            }
        }
        
        if !tagsToDelete.isEmpty {
            print("[HomeViewModel] ✅ Cleaned \(tagsToDelete.count) unused tags")
            // 在 MainActor 上重新加载 tags
            await MainActor.run {
                loadTags()
            }
        }
    }
    
    /// 加载未完成的草稿
    private func loadPendingDrafts() {
        // 打印开发配置
        DevConfig.printConfig()
        
        let drafts = draftManager.loadAllDrafts()
        if !drafts.isEmpty {
            print("[HomeViewModel] Found \(drafts.count) pending drafts")
            
            // 开发模式：只保留最新的一条草稿，删除其他
            if DevConfig.isDevelopmentMode && DevConfig.cleanOldDrafts && drafts.count > 1 {
                // 按更新时间排序，最新的在前
                let sortedDrafts = drafts.sorted { $0.updatedAt > $1.updatedAt }
                
                // 删除除最新一条外的所有草稿
                for (index, draft) in sortedDrafts.enumerated() {
                    if index > 0 {
                        try? draftManager.deleteDraft(id: draft.id)
                        print("[HomeViewModel] 🗑️ Deleted old draft: \(draft.id)")
                    }
                }
                
                print("[HomeViewModel] ✅ Dev mode: Cleaned up \(drafts.count - 1) old drafts, kept 1 newest")
            }
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
        suggestedPrompts = []       // Best Friend Mode
        isAITyping = false          // B-007
        showFullChatView = false    // B-007
        isAnalyzing = false         // B-008
        currentAnalysis = nil       // B-008
        analysisProgressText = ""   // B-008
        isSendingMessage = false    // B-009
        pendingRetryMessage = nil   // B-009
        isGenerating = false        // F-005
        generationProgressText = "" // F-005
        generatedTagNames = []      // F-005
        currentEnvironment = nil    // B-010
        isLoadingEnvironment = false // B-010
        isSavingMedia = false
        isSavingDraft = false
        errorMessage = nil
        selectedStyle = .warm       // Reset style
    }
    
    /// 结束保存 (F-005, B-004, B-008, B-010)
    /// 采用 Optimistic UI + Background Processing 模式
    /// 第一阶段：前台毫秒级响应
    /// 第二阶段：后台静默处理
    func finishAndSave() {
        print("[HomeViewModel] ⚡ Save Memory triggered (Optimistic UI mode)")
        
        guard currentDraft != nil else {
            showErrorMessage("没有可保存的内容")
            return
        }
        
        // ========== 第一阶段：前台立即响应（MainActor，毫秒级）==========
        performImmediateUIUpdate()
    }
    
    // MARK: - 第一阶段：前台立即响应（Optimistic UI）
    
    /// 前台立即响应：锁定快照 → 本地持久化 → UI 乐观更新 → 状态重置 → 关闭页面
    @MainActor
    private func performImmediateUIUpdate() {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("[HomeViewModel] 📍 Phase 1: Immediate UI update starting...")
        
        guard var draft = currentDraft else { return }
        
        // 1️⃣ 锁定数据快照（Draft）
        let snapshotTextInput = userInputText
        let snapshotMessages = chatMessages
        let snapshotAnalysis = currentAnalysis
        let snapshotEnvironment = currentEnvironment
        let snapshotStyle = selectedStyle
        
        // 2️⃣ 更新草稿基本数据
        draft.userInputText = snapshotTextInput.isEmpty ? nil : snapshotTextInput
        draft.messages = snapshotMessages
        draft.isSaved = true
        draft.markProcessing()  // 标记为处理中
        
        // 保存 AI 分析结果（如果有）
        if let analysis = snapshotAnalysis {
            draft.aiAnalysisResult = analysis.description
            draft.isAnalyzed = true
        }
        
        draft.touch()
        
        // 3️⃣ 本地持久化（必须马上写盘）
        do {
            try draftManager.saveDraft(draft)
            print("[HomeViewModel] ✅ Draft persisted to disk: \(draft.id)")
        } catch {
            print("[HomeViewModel] ⚠️ Draft persistence failed: \(error)")
            // 继续流程，不阻断用户
        }
        
        // 4️⃣ UI 乐观更新：立刻插入到主页列表顶部
        if !diaryEntries.contains(where: { $0.id == draft.id }) {
            diaryEntries.insert(draft, at: 0)
            print("[HomeViewModel] ✅ Entry inserted at top of list (processing state)")
        } else {
            // 更新已存在的条目
            if let index = diaryEntries.firstIndex(where: { $0.id == draft.id }) {
                diaryEntries[index] = draft
            }
        }
        
        // 5️⃣ 状态重置（创建页 UI 清空）
        let savedDraftId = draft.id
        resetCreatingState()
        
        // 6️⃣ 关闭页面（立即回浏览模式）
        currentMode = .browsing
        
        let phase1Time = CFAbsoluteTimeGetCurrent() - startTime
        print("[HomeViewModel] ⚡ Phase 1 completed in \(String(format: "%.0f", phase1Time * 1000))ms")
        
        // ========== 第二阶段：后台静默处理（Detached Task）==========
        // 使用 Task.detached 确保不会阻塞 UI
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performBackgroundProcessing(
                draftId: savedDraftId,
                messages: snapshotMessages,
                analysis: snapshotAnalysis,
                environment: snapshotEnvironment,
                style: snapshotStyle
            )
        }
    }
    
    // MARK: - 第二阶段：后台静默处理（Background Processing）
    
    /// 后台静默处理：AI 生成 → 云端上传 → 最终同步
    private func performBackgroundProcessing(
        draftId: UUID,
        messages: [ChatMessage],
        analysis: AIAnalysisResult?,
        environment: EnvironmentContext?,
        style: DiaryStyle
    ) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("[HomeViewModel] 🔄 Phase 2: Background processing starting for \(draftId)...")
        
        // 重新加载草稿（确保使用最新数据）- 在 MainActor 上执行
        guard var draft = await MainActor.run(body: {
            try? draftManager.loadDraft(id: draftId)
        }) else {
            print("[HomeViewModel] ⚠️ Failed to load draft for background processing")
            return
        }
        
        // 获取已存在的标签名称（用于优先复用）
        let existingTagNames = await MainActor.run {
            availableTags
                .filter { $0.id.uuidString != "00000000-0000-0000-0000-000000000000" }
                .map { $0.name }
        }
        
        // ========== 3.1 AI 智能生成（后台）==========
        if !messages.isEmpty {
            await updateEntryInListAsync(draftId) { $0.markAIGenerating() }
            
            // 生成标题 + 总结
            do {
                let result = try await aiService.generateSummary(
                    messages: messages,
                    analysisContext: analysis,
                    style: style,
                    environmentContext: environment
                )
                draft.diarySummary = result.summary
                draft.title = result.title
                draft.style = style.rawValue
                draft.isSummarized = true
                print("[HomeViewModel] ✅ Summary generated: \(result.title)")
            } catch {
                print("[HomeViewModel] ⚠️ Summary generation failed: \(error)")
                // 继续流程，不阻断
            }
            
            // 生成标签
            do {
                let tagNames = try await aiService.generateTags(
                    messages: messages,
                    analysisContext: analysis,
                    style: style,
                    existingTags: existingTagNames
                )
                
                // 关联标签
                await associateTagsWithDraftBackground(tagNames: tagNames, draft: &draft)
                print("[HomeViewModel] ✅ Tags generated: \(tagNames)")
            } catch {
                print("[HomeViewModel] ⚠️ Tag generation failed: \(error)")
            }
            
            // 更新本地持久化
            await MainActor.run {
                try? draftManager.saveDraft(draft)
            }
            
            // 更新 UI 列表中的条目（自动刷新标题/总结/标签）
            let updatedDraft = draft
            await updateEntryInListAsync(draftId) { entry in
                entry.title = updatedDraft.title
                entry.diarySummary = updatedDraft.diarySummary
                entry.tagIds = updatedDraft.tagIds
                entry.isSummarized = updatedDraft.isSummarized
            }
        }
        
        // ========== 3.2 云端静默上传（后台）==========
        await updateEntryInListAsync(draftId) { $0.markUploading() }
        
        let uploadSuccess = await uploadToCloudSilently(draft: &draft)
        
        // ========== 3.3 最终同步 ==========
        if uploadSuccess {
            draft.markSynced()
            draft.markProcessingCompleted()
            print("[HomeViewModel] ✅ Cloud sync completed")
        } else {
            draft.markProcessingFailed(draft.lastErrorMessage ?? "上传失败")
            print("[HomeViewModel] ⚠️ Cloud sync failed (can retry later)")
        }
        
        // 最终写盘保存
        await MainActor.run {
            try? draftManager.saveDraft(draft)
        }
        
        // 更新 UI 列表中的条目（清除处理中遮罩）
        let finalDraft = draft
        await updateEntryInListAsync(draftId) { entry in
            entry = finalDraft
        }
        
        // 刷新标签列表（可能有新标签）
        await MainActor.run {
            loadTags()
        }
        
        let phase2Time = CFAbsoluteTimeGetCurrent() - startTime
        print("[HomeViewModel] ✅ Phase 2 completed in \(String(format: "%.1f", phase2Time))s")
    }
    
    /// 后台关联标签（不使用 MainActor）
    private func associateTagsWithDraftBackground(tagNames: [String], draft: inout DiaryEntry) async {
        var tagIds: [UUID] = []
        
        for tagName in tagNames {
            // 先检查本地是否有同名标签
            let existingTag = await MainActor.run {
                availableTags.first(where: { $0.name == tagName })
            }
            
            if let existingTag = existingTag {
                tagIds.append(existingTag.id)
                continue
            }
            
            // 尝试从云端获取或创建标签
            if networkMonitor.isConnected && SupabaseConfig.shared.isConfigured {
                do {
                    let tag = try await databaseService.findOrCreateTag(name: tagName)
                    tagIds.append(tag.id)
                    
                    // 添加到本地缓存
                    await MainActor.run {
                        if !availableTags.contains(where: { $0.id == tag.id }) {
                            availableTags.append(tag)
                        }
                    }
                } catch {
                    print("[HomeViewModel] Failed to find/create tag '\(tagName)': \(error)")
                    let tempTag = Tag(name: tagName, sortOrder: 100)
                    tagIds.append(tempTag.id)
                }
            } else {
                let tempTag = Tag(name: tagName, sortOrder: 100)
                tagIds.append(tempTag.id)
            }
        }
        
        draft.tagIds = tagIds
    }
    
    /// 静默更新列表中的条目（异步版本，用于后台调用）
    private func updateEntryInListAsync(_ id: UUID, update: @escaping (inout DiaryEntry) -> Void) async {
        await MainActor.run {
            if let index = diaryEntries.firstIndex(where: { $0.id == id }) {
                update(&diaryEntries[index])
            }
        }
    }
    
    /// 静默更新列表中的条目（同步版本，仅在 MainActor 上调用）
    @MainActor
    private func updateEntryInList(_ id: UUID, update: (inout DiaryEntry) -> Void) {
        if let index = diaryEntries.firstIndex(where: { $0.id == id }) {
            update(&diaryEntries[index])
        }
    }
    
    /// 静默上传到云端（不显示 loading，不弹窗）
    private func uploadToCloudSilently(draft: inout DiaryEntry) async -> Bool {
        print("[HomeViewModel] 🔄 Silent cloud upload starting...")
        
        // 检查网络状态
        guard networkMonitor.isConnected else {
            print("[HomeViewModel] ⚠️ Offline, skipping cloud upload")
            draft.markSyncFailed("无网络连接，已保存到本机")
            return false
        }
        
        // 检查 Supabase 配置
        guard SupabaseConfig.shared.isConfigured else {
            print("[HomeViewModel] ⚠️ Supabase not configured, skipping upload")
            draft.markSyncFailed("云端服务未配置")
            return false
        }
        
        draft.markSyncing()
        var uploadSuccess = true
        
        // 1️⃣ 上传媒体和缩略图到 Storage
        let result = await storageService.uploadMediaWithThumbnail(
            localMediaPath: draft.localMediaPath ?? "",
            localThumbnailPath: draft.thumbnailPath,
            diaryId: draft.id,
            mediaType: draft.mediaType
        )
        
        if let mediaResult = result.mediaResult {
            draft.updateCloudMedia(path: mediaResult.path, url: mediaResult.publicURL)
            print("[HomeViewModel] ✅ Media uploaded: \(mediaResult.path)")
        } else if !result.errors.isEmpty {
            uploadSuccess = false
        }
        
        if let thumbResult = result.thumbnailResult {
            draft.updateCloudThumbnail(path: thumbResult.path, url: thumbResult.publicURL)
        }
        
        // 2️⃣ 保存日记到数据库
        do {
            // 保留原来的 tagIds 和 messages（upsert 可能不返回）
            let originalTagIds = draft.tagIds
            let originalMessages = draft.messages
            
            let savedDiary = try await databaseService.upsertDiary(draft)
            draft = savedDiary
            
            // 恢复 tagIds 和 messages（如果 upsert 没有返回）
            if draft.tagIds.isEmpty && !originalTagIds.isEmpty {
                draft.tagIds = originalTagIds
            }
            if draft.messages.isEmpty && !originalMessages.isEmpty {
                draft.messages = originalMessages
            }
            print("[HomeViewModel] ✅ Diary saved to database")
            
            // 3️⃣ 保存聊天消息
            if !draft.messages.isEmpty {
                try await databaseService.saveMessages(draft.messages, for: draft.id)
                print("[HomeViewModel] ✅ Messages saved to database")
            }
            
            // 4️⃣ 保存标签关联
            if !draft.tagIds.isEmpty {
                try await databaseService.saveDiaryTags(diaryId: draft.id, tagIds: draft.tagIds)
                print("[HomeViewModel] ✅ Tags saved to database")
            }
            
        } catch {
            print("[HomeViewModel] ⚠️ Database save failed: \(error)")
            draft.markSyncFailed(error.localizedDescription)
            uploadSuccess = false
        }
        
        return uploadSuccess
    }
    
    /// 执行完整的保存流程（F-005）- 保留用于兼容
    @MainActor
    private func performFinishAndSave() async {
        // 新实现使用 performImmediateUIUpdate()
        performImmediateUIUpdate()
    }
    
    /// 将生成的标签名称关联到草稿（F-005）
    @MainActor
    private func associateTagsWithDraft(tagNames: [String], draft: inout DiaryEntry) async {
        var tagIds: [UUID] = []
        
        for tagName in tagNames {
            // 先检查本地是否有同名标签
            if let existingTag = availableTags.first(where: { $0.name == tagName }) {
                tagIds.append(existingTag.id)
                continue
            }
            
            // 尝试从云端获取或创建标签
            if networkMonitor.isConnected && SupabaseConfig.shared.isConfigured {
                do {
                    let tag = try await databaseService.findOrCreateTag(name: tagName)
                    tagIds.append(tag.id)
                    
                    // 添加到本地缓存
                    if !availableTags.contains(where: { $0.id == tag.id }) {
                        availableTags.append(tag)
                    }
                } catch {
                    print("[HomeViewModel] Failed to find/create tag '\(tagName)': \(error)")
                    // 创建临时本地标签
                    let tempTag = Tag(name: tagName, sortOrder: availableTags.count)
                    tagIds.append(tempTag.id)
                }
            } else {
                // 离线模式：创建临时本地标签
                let tempTag = Tag(name: tagName, sortOrder: availableTags.count)
                tagIds.append(tempTag.id)
            }
        }
        
        draft.tagIds = tagIds
        print("[HomeViewModel] Associated \(tagIds.count) tags with draft")
    }
    
    // MARK: - 云端上传 (B-004, B-005)
    
    /// 上传媒体到 Supabase Storage 并保存到数据库（旧版，保留兼容）
    /// 注意：新的保存流程使用 `uploadToCloudSilently` 静默上传
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
        
        // 使用静默上传方法
        let uploadSuccess = await uploadToCloudSilently(draft: &draft)
        
        // 更新同步状态
        if uploadSuccess {
            draft.markSynced()
            uploadProgressText = "保存完成"
            print("[HomeViewModel] Cloud sync completed")
        } else {
            uploadProgressText = "部分保存失败"
            print("[HomeViewModel] Cloud sync partial failure")
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
        isGenerating = false
        generationProgressText = ""
        
        // 切换回浏览模式
        currentMode = .browsing
        resetCreatingState()
        
        // 重新加载日记列表和标签
        loadDiariesForCurrentTag()
        loadTags()  // F-005: 重新加载标签（可能有新标签）
        
        print("[HomeViewModel] Save flow completed")
    }
    
    /// 手动重试云端同步（用于同步失败的日记）
    func retryCloudSync(for entryId: UUID) {
        print("[HomeViewModel] 🔄 Retrying cloud sync for: \(entryId)")
        
        Task { [weak self] in
            guard let self = self else { return }
            
            // 在 MainActor 上加载草稿
            guard var draft = await MainActor.run(body: {
                try? self.draftManager.loadDraft(id: entryId)
            }) else {
                print("[HomeViewModel] ⚠️ Failed to load draft for retry")
                return
            }
            
            guard draft.syncStatus == .failed || draft.processingState == .failed else {
                print("[HomeViewModel] ⚠️ Entry is not in failed state")
                return
            }
            
            // 重置状态
            draft.processingState = .uploading
            draft.lastErrorMessage = nil
            await self.updateEntryInListAsync(entryId) { $0.processingState = .uploading }
            
            // 重试上传
            let success = await self.uploadToCloudSilently(draft: &draft)
            
            if success {
                draft.markSynced()
                draft.markProcessingCompleted()
            } else {
                draft.markProcessingFailed(draft.lastErrorMessage ?? "上传失败")
            }
            
            let finalDraft = draft
            await MainActor.run {
                try? self.draftManager.saveDraft(finalDraft)
            }
            await self.updateEntryInListAsync(entryId) { $0 = finalDraft }
        }
    }
    
    /// 旧版重试方法（兼容）
    func retryCloudSync() {
        guard let draft = currentDraft else { return }
        guard draft.syncStatus == .failed else { return }
        retryCloudSync(for: draft.id)
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
                    let errorMsg = error.localizedDescription
                    
                    // 静默处理 "No speech detected" 错误
                    if errorMsg.contains("No speech detected") || errorMsg.contains("没有检测到语音") {
                        print("[HomeViewModel] Speech recognition ended without speech (ignored)")
                        // 确保清除可能的旧错误，并且不显示弹窗
                        self?.speechErrorMessage = nil
                        return
                    }
                    
                    self?.speechErrorMessage = errorMsg
                    self?.showErrorMessage(errorMsg)
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
        suggestedPrompts = [] // 清除旧的建议
        
        do {
            // 调用 AI 服务（Best Friend Mode: 传递环境上下文）
            let response = try await aiService.chat(
                messages: chatMessages,
                analysisContext: currentAnalysis,
                environmentContext: currentEnvironment,
                diaryId: draft.id,
                style: selectedStyle
            )
            
            // 解析结构化响应（Best Friend Mode）
            let parsed = AIChatResponse.parse(from: response)
            
            // 添加 AI 回复
            let aiMsg = ChatMessage(sender: .ai, content: parsed.assistantReply)
            chatMessages.append(aiMsg)
            
            // 更新建议话题（用于用户卡住时显示）
            if let prompts = parsed.suggestedPrompts, !prompts.isEmpty {
                suggestedPrompts = prompts
                print("[HomeViewModel] Suggested prompts: \(prompts)")
            }
            
            // 保存到本机
            updateDraftMessages()
            
            print("[HomeViewModel] AI response received: \(parsed.assistantReply.prefix(50))...")
            
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
    
    /// 触发即时欢迎消息 + 后台分析 + 环境获取 (B-007, B-008, B-010)
    /// 策略：先立即响应用户（< 0.5s），后台静默分析和获取环境
    private func triggerInitialAIResponse(for mediaType: MediaType) {
        // 1. 立即发送欢迎消息（不等待分析）
        sendInstantWelcomeMessage(for: mediaType)
        
        // 2. 后台并行执行：AI 分析 + 环境获取
        Task { @MainActor in
            // 并行获取环境信息（不阻塞）
            await fetchEnvironmentQuietly()
        }
        
        // 3. 后台静默分析（如果有图片）
        guard let image = selectedMediaImage else {
            print("[HomeViewModel] No image for background analysis")
            return
        }
        
        // 标记后台分析中（不显示 typing 动画）
        isAnalyzing = true
        analysisProgressText = ""  // 不显示进度，静默进行
        
        Task { @MainActor in
            await performBackgroundAnalysis(image: image, mediaType: mediaType)
        }
    }
    
    /// 后台静默获取环境信息 (B-010)
    @MainActor
    private func fetchEnvironmentQuietly() async {
        print("[HomeViewModel] 🌤️ Fetching environment context...")
        isLoadingEnvironment = true
        
        // 使用新的 EnvironmentService API
        // 如果已有数据则使用缓存，否则等待刷新
        if environmentService.hasValidData, let context = environmentService.environmentContext {
            currentEnvironment = context
            isLoadingEnvironment = false
            print("[HomeViewModel] 🌤️ Environment ready (cached): \(context.aiDescription)")
            return
        }
        
        // 等待环境服务刷新完成
        await environmentService.refreshIfNeeded()
        
        if let context = environmentService.environmentContext {
            currentEnvironment = context
            print("[HomeViewModel] 🌤️ Environment ready: \(context.aiDescription)")
        } else {
            print("[HomeViewModel] ⚠️ Environment not available (location denied or failed)")
        }
        
        isLoadingEnvironment = false
    }
    
    /// 发送即时欢迎消息（< 0.5s 响应）(B-010 优化)
    private func sendInstantWelcomeMessage(for mediaType: MediaType) {
        isAITyping = false
        
        // B-010: 获取时间上下文（立即可用，不需要网络）
        let timeContext = environmentService.getTimeContext()
        let greeting = timeContext.timeInfo.period.greeting
        
        // 根据媒体类型 + 时间生成欢迎消息
        let content: String
        switch mediaType {
        case .photo:
            content = "\(greeting)这张照片看起来很有故事！想聊聊是在什么情况下拍的吗？"
        case .video:
            content = "\(greeting)这段视频记录了什么特别的时刻呢？我很想听你分享～"
        }
        
        let welcomeMsg = ChatMessage(sender: .ai, content: content)
        chatMessages.append(welcomeMsg)
        updateDraftMessages()
        
        print("[HomeViewModel] ⚡ Instant welcome sent (< 0.5s): \(greeting)")
    }
    
    /// 后台静默分析（不阻塞用户交互）(B-008)
    @MainActor
    private func performBackgroundAnalysis(image: UIImage, mediaType: MediaType) async {
        print("[HomeViewModel] 🔄 Starting background analysis...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 调用 AI 服务分析媒体
            let analysis = try await aiService.analyzeImage(
                image,
                mediaType: mediaType,
                userContext: nil  // 后台分析不需要用户上下文
            )
            
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("[HomeViewModel] ✅ Background analysis done in \(String(format: "%.1f", elapsed))s")
            
            // 保存分析结果（用于后续对话）
            currentAnalysis = analysis
            
            // 更新草稿的分析结果 (D-004)
            if var draft = currentDraft {
                draft.aiAnalysisResult = analysis.description
                draft.isAnalyzed = true
                draft.touch()
                currentDraft = draft
                
                // 静默保存到本机
                try? draftManager.saveDraft(draft)
            }
            
            isAnalyzing = false
            print("[HomeViewModel] 📝 Analysis saved:")
            print("   描述: \(analysis.description)")
            print("   标签: \(analysis.sceneTags?.joined(separator: ", ") ?? "无")")
            print("   情绪: \(analysis.mood ?? "未知")")
            print("   有人物: \(analysis.hasPeople == true ? "是" : "否")")
            
        } catch {
            // 分析失败，静默处理（不打扰用户）
            print("[HomeViewModel] ⚠️ Background analysis failed: \(error)")
            isAnalyzing = false
            
            // 记录错误但不显示给用户
            if var draft = currentDraft {
                draft.lastErrorMessage = "AI 分析失败：\(error.localizedDescription)"
                currentDraft = draft
            }
        }
    }
    
    /// 执行 AI 分析 (B-008) - 保留用于手动重试
    @MainActor
    private func performAIAnalysis(image: UIImage, mediaType: MediaType) async {
        print("[HomeViewModel] Starting AI analysis for \(mediaType.rawValue)")
        isAITyping = true
        
        do {
            let analysis = try await aiService.analyzeImage(
                image,
                mediaType: mediaType,
                userContext: userInputText.isEmpty ? nil : userInputText
            )
            
            currentAnalysis = analysis
            
            if var draft = currentDraft {
                draft.aiAnalysisResult = analysis.description
                draft.isAnalyzed = true
                draft.touch()
                currentDraft = draft
                try? draftManager.saveDraft(draft)
            }
            
            isAnalyzing = false
            analysisProgressText = ""
            isAITyping = false
            
            // 手动重试时，追加一条基于分析的消息
            sendAnalysisBasedWelcomeMessage(analysis: analysis, mediaType: mediaType)
            
        } catch {
            print("[HomeViewModel] AI analysis failed: \(error)")
            isAnalyzing = false
            analysisProgressText = ""
            isAITyping = false
            
            if var draft = currentDraft {
                draft.lastErrorMessage = "AI 分析失败：\(error.localizedDescription)"
                currentDraft = draft
            }
            
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
