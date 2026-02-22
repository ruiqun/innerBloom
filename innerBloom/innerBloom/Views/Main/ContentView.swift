//
//  ContentView.swift
//  innerBloom
//
//  主页视图 - S-001
//  Style: Cinematic Dark Void
//  B-003: 完善媒体选择（支持照片/视频）与草稿保存
//  B-016: 添加设定入口
//  B-017: 多语言支持
//

import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
    
    // MARK: - Properties
    
    @Bindable private var viewModel = HomeViewModel.shared
    @Bindable private var settingsManager = SettingsManager.shared
    @Bindable private var localization = LocalizationManager.shared
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showSettings = false  // B-016: 设定页面
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 全局背景：暖黑渐层 + 顶部聚光灯
            ZStack {
                Theme.warmBlackGradient
                    .ignoresSafeArea()
                
                // 顶部聚光灯效果 (Royal Spotlight)
                RadialGradient(
                    gradient: Gradient(colors: [Theme.goldLight.opacity(0.08), Color.clear]),
                    center: .top,
                    startRadius: 0,
                    endRadius: 600
                )
                .ignoresSafeArea()
            }
            
            // 极轻微杂讯质感 (Optional)
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)
                .ignoresSafeArea()
            
            // 内容区域：僅瀏覽模式忽略底部安全區；建立模式保留鍵盤安全區，避免輸入時對話被鍵盤蓋住
            VStack {
                if viewModel.currentMode == .browsing {
                    browsingModeView
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    creatingModeView
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            
            // 保存中/上传中/生成中遮罩 (B-004, F-005)
            if viewModel.isSavingMedia || viewModel.isUploading || viewModel.isGenerating {
                savingOverlay
            }
        }
        // 照片/视频选择器
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            handleMediaSelection(newValue)
        }
        // B-017: 错误提示（本地化）
        .alert(String.localized(.hint), isPresented: $viewModel.showError) {
            Button(String.localized(.confirm)) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? String.localized(.unknownError))
        }
        // 完整聊天视图 (B-007)
        .sheet(isPresented: Binding(
            get: { viewModel.showFullChatView },
            set: { viewModel.showFullChatView = $0 }
        )) {
            fullChatSheet
        }
        // 日记详情视图 (B-012)
        .fullScreenCover(item: $viewModel.selectedDiary) { entry in
            diaryDetailCover(entry: entry)
        }
        // 隐藏默认 NavigationBar，使用自定义布局
        .navigationBarHidden(true)
        // B-016: preferredColorScheme 已移至 innerBloomApp 全局统一设置
        // B-016: 设定页面
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        // B-026: 用量限制提示（S-006）
        .sheet(isPresented: $viewModel.showUsageLimit) {
            UsageLimitView(
                limitType: viewModel.usageLimitType,
                onUpgrade: {
                    viewModel.showPremiumFromUsage = true
                }
            )
        }
        // B-026: 由 S-006 導入的 Premium 付費牆
        .sheet(isPresented: $viewModel.showPremiumFromUsage) {
            PremiumView()
        }
        // B-016: 启动时应用外观模式
        .onAppear {
            settingsManager.applyAppearanceMode()
        }
        // B-017: 监听语言变化，刷新视图
        .id(localization.languageChangeId)
    }
    
    // MARK: - 完整聊天视图 Sheet (B-007)
    
    private var fullChatSheet: some View {
        NavigationStack {
            ChatView(
                messages: viewModel.chatMessages,
                isAITyping: viewModel.isAITyping,
                onSendMessage: { text in
                    viewModel.sendMessage(text)
                }
            )
            .navigationTitle(String.localized(.conversation))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String.localized(.done)) {
                        viewModel.showFullChatView = false
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - 日记详情视图 FullScreenCover (B-012)
    
    private func diaryDetailCover(entry: DiaryEntry) -> some View {
        DiaryDetailView(
            entry: entry,
            onTagSelected: { tag in
                viewModel.selectTagFromDetail(tag)
            },
            onDelete: {
                viewModel.deleteDiary(entry)
            }
        )
    }
    
    // MARK: - 保存中/上传中/生成中遮罩 (B-004, F-005)
    
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // F-005: 根据状态显示不同图标
                ZStack {
                    if viewModel.isGenerating {
                        // AI 生成中显示闪烁的 AI 图标
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.accent)
                            .symbolEffect(.pulse)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                            .scaleEffect(1.5)
                    }
                }
                .frame(height: 40)
                
                Text(overlayStatusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
    
    /// 遮罩状态文字
    /// B-017: 支持多语言
    private var overlayStatusText: String {
        // F-005: AI 生成进度优先显示
        if viewModel.isGenerating {
            return viewModel.generationProgressText.isEmpty ? String.localized(.aiGenerating) : viewModel.generationProgressText
        } else if viewModel.isUploading {
            return viewModel.uploadProgressText.isEmpty ? String.localized(.uploading) : viewModel.uploadProgressText
        } else if viewModel.isSavingMedia {
            return String.localized(.saving)
        }
        return String.localized(.processing)
    }
    
    // MARK: - 搜索框 (B-014, F-008)
    // B-017: 支持多语言
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            
            // 搜索输入框
            TextField(String.localized(.searchDiary), text: $viewModel.searchText)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()
                .onSubmit {
                    viewModel.performSearch()
                }
            
            // 清除按钮（仅在有输入时显示）
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 搜索按钮（仅在有输入时显示）
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.performSearch()
                }) {
                    Text(String.localized(.search))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    /// 搜索结果提示 (B-014)
    /// B-017: 支持多语言
    private var searchResultsHeader: some View {
        HStack {
            Text("\(String.localized(.search))「\(viewModel.searchText)」")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            
            if let results = viewModel.searchResults {
                Text(String.localized(.foundDiaries, args: results.count))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.accent)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.clearSearch()
            }) {
                Text(String.localized(.clear))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(.horizontal, 24)
    }
    
    /// B-015: 同步失败 Banner
    /// B-017: 支持多语言
    private var syncFailedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String.localized(.syncFailedCount, args: viewModel.failedEntriesCount))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                
                Text(String.localized(.savedLocallyRetryLater))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.retryAllFailedEntries()
            }) {
                Text(String.localized(.retryAll))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - 浏览模式 (极简列表)
    
    private var browsingModeView: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                // 頂部 Header（「InnerBloom」標題：僅此處用較大字體，其他列表仍用 titleFont 16pt）
                HStack {
                    Text("InnerBloom")
                        .font(Theme.royalFont(size: 22, weight: .medium))
                        .tracking(Theme.titleTracking)
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    // B-016: 设定按钮
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // B-014: 搜索框
                searchBarView
                    .padding(.horizontal, 24)
                
                // 标签图块 (需要调整 TagChipsView 样式以匹配)
                // 暂时复用，建议后续优化 TagChipsView 样式
                TagChipsView(
                    tags: viewModel.availableTags,
                    selectedTag: viewModel.selectedTag,
                    onSelectTag: { tag in
                        viewModel.clearSearch()  // 切换标签时清除搜索
                        viewModel.selectTag(tag)
                    }
                )
                .padding(.leading, 8)
                
                // B-014: 搜索结果提示
                if viewModel.isShowingSearchResults {
                    searchResultsHeader
                }
                
                // B-015: 同步失败 Banner
                if viewModel.hasFailedEntries && !viewModel.isShowingSearchResults {
                    syncFailedBanner
                }
                
                // 日记列表（B-013：支持下拉刷新）
                // B-017: 支持多语言
                ScrollView {
                    DiaryListView(
                        entries: viewModel.displayEntries,  // B-014: 使用 displayEntries
                        currentTagName: viewModel.isShowingSearchResults ? String.localized(.searchResult) : viewModel.selectedTag.name,
                        isLoading: viewModel.isLoading || viewModel.isSearching,
                        onTapEntry: { entry in
                            // Detail
                            viewModel.showDiaryDetail(entry)
                        },
                        onRetry: { entry in  // B-015: 重试回调
                            viewModel.retryCloudSync(for: entry.id)
                        },
                        onEntryAppear: { entry in  // B-020: 无限滚动分页
                            viewModel.onDiaryAppear(entry)
                        },
                        isLoadingMore: viewModel.isLoadingMore,
                        hasMoreData: viewModel.hasMoreData
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }
            
            // 浮动新增按钮（右下角）
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewModel.enterCreatingMode()
                }
            }) {
                Circle()
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .light).bold())
                            .foregroundColor(Theme.accent)
                    )
                    .background(
                        Circle()
                            .fill(Theme.accent.opacity(0.7))
                            .blur(radius: 5)
                    )
            }
            // .opacity(0.75)
            .padding(.trailing, 24)
            .padding(.bottom, 40)
        }
        // 手势支持
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            viewModel.enterCreatingMode()
                        }
                    }
                }
        )
    }
    
    // MARK: - 创建模式 (Cinematic Main Visual)
    
    private var creatingModeView: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            VStack(spacing: 0) {
                // 1. 核心主视觉 + 聊天 (整体布局)
                VStack {
                    // 顶部留白
                    Spacer()
                        .frame(height: screenHeight * 0.12)
                    
                    // B-016: 风格选择器移至设定页面，此处移除
                    
                    // 图片容器
                    ZStack {
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            CircleImageView(image: viewModel.selectedMediaImage)
                        }
                        .buttonStyle(.plain)
                        
                        // 聊天消息覆盖层 - 完全居中在图片内 (B-007)
                        ChatOverlayView(
                            messages: viewModel.chatMessages,
                            isAITyping: viewModel.isAITyping,
                            suggestedPrompts: viewModel.suggestedPrompts,
                            onTapToExpand: {
                                viewModel.toggleFullChatView()
                            },
                            onSelectPrompt: { prompt in
                                viewModel.sendMessage(prompt)
                            }
                        )
                        .frame(
                            width: screenWidth - 100,
                            height: screenWidth - 100,
                            alignment: .center
                        )
                        .allowsHitTesting(viewModel.chatMessages.count > 0)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                // 2. 底部操作区 (输入 + 按钮)
                VStack(spacing: 16) {
                    // 输入区 (带发送按钮)
                    InputAreaView(
                        inputText: $viewModel.userInputText,
                        isRecording: viewModel.isRecording,
                        audioLevel: viewModel.audioLevel,
                        transcribingText: viewModel.transcribingText,
                        isSending: viewModel.isSendingMessage,
                        onStartRecording: { viewModel.startRecording() },
                        onStopRecording: { viewModel.stopRecording() },
                        onSend: {
                            let text = viewModel.userInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                viewModel.sendMessage(text)
                                viewModel.userInputText = ""
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    
                    // 操作按钮（返回 + Save Memory）
                    ActionButtonsView(
                        onBack: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                viewModel.cancelCreating()
                            }
                        },
                        onSaveMemory: {
                            viewModel.finishAndSave()
                        },
                        canSave: viewModel.selectedMediaImage != nil && viewModel.chatMessages.count > 0,
                        isSaving: viewModel.isSavingMedia || viewModel.isGenerating
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .background(
                    // 底部区域背景渐变，与主背景融合
                    LinearGradient(
                        colors: [Theme.background.opacity(0), Theme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .offset(y: -40),
                    alignment: .top
                )
            }
            .background(Theme.background)
            // 手势支持
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width > 50 {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                viewModel.cancelCreating()
                            }
                        }
                    }
            )
        }
    }
    
    // MARK: - Logic (B-003)
    
    /// 处理媒体选择（支持照片和视频）
    private func handleMediaSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        // 立即清除 PhotosPicker 引用，让系统尽早释放 PHPicker session
        // 减少延迟回扫相簿导致的主线程阻塞
        selectedPhotoItem = nil
        
        Task {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
                await handleVideoSelection(item)
            } else {
                await handleImageSelection(item)
            }
        }
    }
    
    /// 处理图片选择
    /// B-017: 支持多语言错误提示
    private func handleImageSelection(_ item: PhotosPickerItem) async {
        let totalStart = CFAbsoluteTimeGetCurrent()
        print("[ContentView] 🔍 handleImageSelection START")
        
        do {
            let loadStart = CFAbsoluteTimeGetCurrent()
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run { showError(String.localized(.cannotReadPhoto)) }
                return
            }
            print("[ContentView] 🔍 PhotosPicker loadTransferable: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - loadStart) * 1000))ms, dataSize: \(data.count / 1024)KB")
            
            let decodeStart = CFAbsoluteTimeGetCurrent()
            let image: UIImage? = await Task.detached(priority: .userInitiated) {
                let decodeInnerStart = CFAbsoluteTimeGetCurrent()
                guard let fullImage = UIImage(data: data) else { return nil as UIImage? }
                print("[ContentView] 🔍 UIImage(data:) decode: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - decodeInnerStart) * 1000))ms, size: \(fullImage.size)")
                
                let maxDimension: CGFloat = 1200
                let size = fullImage.size
                if max(size.width, size.height) <= maxDimension {
                    print("[ContentView] 🔍 No pre-scale needed (within \(maxDimension)pt)")
                    return fullImage
                }
                let scaleStart = CFAbsoluteTimeGetCurrent()
                let scale = maxDimension / max(size.width, size.height)
                let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let scaled = renderer.image { _ in fullImage.draw(in: CGRect(origin: .zero, size: newSize)) }
                print("[ContentView] 🔍 Pre-scale \(size) → \(newSize): \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - scaleStart) * 1000))ms")
                return scaled
            }.value
            print("[ContentView] 🔍 Decode+Scale total: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - decodeStart) * 1000))ms")
            
            guard let image else {
                await MainActor.run { showError(String.localized(.cannotReadPhoto)) }
                return
            }
            
            let setMediaStart = CFAbsoluteTimeGetCurrent()
            await MainActor.run {
                print("[ContentView] 🔍 About to call setSelectedMedia on MainActor")
                viewModel.setSelectedMedia(image: image)
            }
            print("[ContentView] 🔍 setSelectedMedia returned: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - setMediaStart) * 1000))ms")
            
            print("[ContentView] ✅ handleImageSelection TOTAL: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - totalStart) * 1000))ms")
            
        } catch {
            await MainActor.run { showError(String.localized(.photoReadFailed) + error.localizedDescription) }
        }
    }
    
    /// 处理视频选择
    /// B-017: 支持多语言错误提示
    private func handleVideoSelection(_ item: PhotosPickerItem) async {
        do {
            // 加载视频数据（使用 Movie 类型）
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                await MainActor.run { showError(String.localized(.cannotReadVideo)) }
                return
            }
            
            // 读取视频数据
            let videoData = try Data(contentsOf: movie.url)
            
            // 生成视频缩略图
            let thumbnail = await generateVideoThumbnail(from: movie.url)
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: movie.url)
            
            guard let thumbImage = thumbnail else {
                await MainActor.run { showError(String.localized(.cannotGeneratePreview)) }
                return
            }
            
            await MainActor.run {
                viewModel.setSelectedMedia(videoData: videoData, thumbnail: thumbImage)
            }
            
            print("[ContentView] Video selected successfully")
            
        } catch {
            await MainActor.run { showError(String.localized(.videoReadFailed) + error.localizedDescription) }
        }
    }
    
    /// 生成视频缩略图
    private func generateVideoThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            print("[ContentView] Failed to generate thumbnail: \(error)")
            return nil
        }
    }
    
    /// 显示错误
    @MainActor
    private func showError(_ message: String) {
        viewModel.errorMessage = message
        viewModel.showError = true
    }
}

// MARK: - Video Transferable (B-003)

/// 视频传输类型，用于 PhotosPicker
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // 复制到临时目录
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                "\(UUID().uuidString).mp4"
            )
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

#Preview {
    ContentView()
}
