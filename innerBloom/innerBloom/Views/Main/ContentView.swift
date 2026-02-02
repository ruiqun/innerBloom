//
//  ContentView.swift
//  innerBloom
//
//  主页视图 - S-001
//  Style: Cinematic Dark Void
//  B-003: 完善媒体选择（支持照片/视频）与草稿保存
//

import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
    
    // MARK: - Properties
    
    @Bindable private var viewModel = HomeViewModel.shared
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 全局背景：几乎纯黑
            Theme.background
                .ignoresSafeArea()
            
            // 内容区域
            VStack {
                if viewModel.currentMode == .browsing {
                    browsingModeView
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
        // 错误提示
        .alert("提示", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "发生未知错误")
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
        .preferredColorScheme(.dark)
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
            .navigationTitle("对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
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
    private var overlayStatusText: String {
        // F-005: AI 生成进度优先显示
        if viewModel.isGenerating {
            return viewModel.generationProgressText.isEmpty ? "正在生成..." : viewModel.generationProgressText
        } else if viewModel.isUploading {
            return viewModel.uploadProgressText.isEmpty ? "正在上传..." : viewModel.uploadProgressText
        } else if viewModel.isSavingMedia {
            return "保存中..."
        }
        return "处理中..."
    }
    
    // MARK: - 浏览模式 (极简列表)
    
    private var browsingModeView: some View {
        VStack(spacing: 20) {
            // 顶部 Header
            HStack {
                Text("MEMORY")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .tracking(2)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button(action: {
                    // Settings
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // 标签图块 (需要调整 TagChipsView 样式以匹配)
            // 暂时复用，建议后续优化 TagChipsView 样式
            TagChipsView(
                tags: viewModel.availableTags,
                selectedTag: viewModel.selectedTag,
                onSelectTag: { tag in
                    viewModel.selectTag(tag)
                }
            )
            .padding(.leading, 8)
            
            // 日记列表
            ScrollView {
                DiaryListView(
                    entries: viewModel.diaryEntries,
                    currentTagName: viewModel.selectedTag.name,
                    isLoading: viewModel.isLoading,
                    onTapEntry: { entry in
                        // Detail
                        viewModel.showDiaryDetail(entry)
                    }
                )
                .padding(.top, 16)
            }
            
            Spacer()
            
            // 底部操作栏 (模拟 TabBar 位置，放置新增入口)
            HStack {
                Spacer()
                
                // 极简新增按钮
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
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(Theme.accent)
                        )
                        .background(
                            Circle()
                                .fill(Theme.accent.opacity(0.1))
                                .blur(radius: 5)
                        )
                }
                .padding(.bottom, 20)
                .padding(.trailing, 24)
            }
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
                        .frame(height: screenHeight * 0.08)
                    
                    // 风格选择器
                    StyleSelectorView(selectedStyle: $viewModel.selectedStyle)
                        .padding(.bottom, 16)
                    
                    // 图片容器
                    ZStack {
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            ParticleImageView(image: viewModel.selectedMediaImage)
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
        
        Task {
            do {
                // 判断媒体类型
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
                    // 视频处理
                    await handleVideoSelection(item)
                } else {
                    // 图片处理
                    await handleImageSelection(item)
                }
            }
            
            // 清除选择状态
            await MainActor.run {
                selectedPhotoItem = nil
            }
        }
    }
    
    /// 处理图片选择
    private func handleImageSelection(_ item: PhotosPickerItem) async {
        do {
            // 加载图片数据
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run { showError("无法读取照片") }
                return
            }
            
            await MainActor.run {
                viewModel.setSelectedMedia(image: image)
            }
            
            print("[ContentView] Image selected successfully")
            
        } catch {
            await MainActor.run { showError("照片读取失败：\(error.localizedDescription)") }
        }
    }
    
    /// 处理视频选择
    private func handleVideoSelection(_ item: PhotosPickerItem) async {
        do {
            // 加载视频数据（使用 Movie 类型）
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                await MainActor.run { showError("无法读取影片") }
                return
            }
            
            // 读取视频数据
            let videoData = try Data(contentsOf: movie.url)
            
            // 生成视频缩略图
            let thumbnail = await generateVideoThumbnail(from: movie.url)
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: movie.url)
            
            guard let thumbImage = thumbnail else {
                await MainActor.run { showError("无法生成影片预览") }
                return
            }
            
            await MainActor.run {
                viewModel.setSelectedMedia(videoData: videoData, thumbnail: thumbImage)
            }
            
            print("[ContentView] Video selected successfully")
            
        } catch {
            await MainActor.run { showError("影片读取失败：\(error.localizedDescription)") }
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
