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
    
    @State private var viewModel = HomeViewModel()
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
            
            // 保存中/上传中遮罩 (B-004)
            if viewModel.isSavingMedia || viewModel.isUploading {
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
    
    // MARK: - 保存中/上传中遮罩 (B-004)
    
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(1.5)
                
                Text(overlayStatusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
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
        if viewModel.isUploading {
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
            
            ZStack {
                // 1. 顶部控制栏 (ZStack 最底层，但位置在顶部)
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                viewModel.cancelCreating()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Theme.textSecondary)
                                .padding()
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .zIndex(10) // 确保返回按钮可点击
                
                // 2. 核心主视觉 + 聊天 (整体布局)
                VStack {
                    // 顶部留白调整：往上 1/5 的位置 -> 约占屏幕高度的 10% 顶部留白，视觉重心偏上
                    Spacer()
                        .frame(height: screenHeight * 0.1)
                    
                    // 图片容器
                    ZStack {
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            ParticleImageView(image: viewModel.selectedMediaImage)
                        }
                        .buttonStyle(.plain)
                        
                        // 聊天消息覆盖层 - 完全居中在图片内 (B-007)
                        // 动态计算宽度：屏幕宽度 - 左右margin - 图片内部留白
                        ChatOverlayView(
                            messages: viewModel.chatMessages,
                            isAITyping: viewModel.isAITyping,
                            onTapToExpand: {
                                viewModel.toggleFullChatView()
                            }
                        )
                        .frame(
                            width: screenWidth - 100,
                            height: screenWidth - 100,
                            alignment: .center
                        )
                        .allowsHitTesting(viewModel.chatMessages.count > 0) // 有消息时可点击展开
                    }
                    
                    Spacer() // 下方占满剩余空间，推到上方
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // 3. 底部操作区 (输入 + 按钮)
            VStack(spacing: 24) {
                Spacer()
                
                // 输入区 (B-006: 集成语音输入)
                InputAreaView(
                    inputText: $viewModel.userInputText,
                    isRecording: viewModel.isRecording,
                    audioLevel: viewModel.audioLevel,
                    transcribingText: viewModel.transcribingText,
                    onStartRecording: { viewModel.startRecording() },
                    onStopRecording: { viewModel.stopRecording() }
                )
                // 监听回车发送
                .onSubmit {
                    viewModel.sendMessage(viewModel.userInputText)
                    viewModel.userInputText = ""
                }
                .padding(.horizontal, 24)
                
                // 操作按钮
                ActionButtonsView(
                    onCancel: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            viewModel.cancelCreating()
                        }
                    },
                    onFinishSave: {
                        viewModel.finishAndSave()
                    },
                    canSave: viewModel.selectedMediaImage != nil,
                    isSaving: false
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                }
            }
            .background(Theme.background) // 确保覆盖
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
