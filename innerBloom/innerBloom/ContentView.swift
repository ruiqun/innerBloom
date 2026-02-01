//
//  ContentView.swift
//  innerBloom
//
//  主页视图 - S-001
//  Style: Cinematic Dark Void
//

import SwiftUI
import PhotosUI

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
        }
        // 照片选择器
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            handlePhotoSelection(newValue)
        }
        // 隐藏默认 NavigationBar，使用自定义布局
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
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
                // 顶部留白，约占 1/5 屏幕高度
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * 0.15)
                
                // 图片容器
                ZStack {
                    Button(action: {
                        showPhotoPicker = true
                    }) {
                        // 使用新的粒子化图片组件
                        ParticleImageView(image: viewModel.selectedMediaImage)
                    }
                    .buttonStyle(.plain)
                    
                    // 聊天消息覆盖层 - 居中显示在图片内
                    ChatOverlayView(messages: viewModel.chatMessages)
                        .frame(width: 260, height: 260) // 限制在图片大小范围内
                        .allowsHitTesting(false) // 允许点击穿透到图片
                }
                
                Spacer() // 推到上方
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // 3. 底部操作区 (输入 + 按钮)
            VStack(spacing: 24) {
                Spacer()
                
                // 输入区
                InputAreaView(
                    inputText: $viewModel.userInputText,
                    isRecording: viewModel.isRecording,
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
    
    // MARK: - Logic
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    viewModel.setSelectedMedia(image: image)
                }
            }
            selectedPhotoItem = nil
        }
    }
}

#Preview {
    ContentView()
}
