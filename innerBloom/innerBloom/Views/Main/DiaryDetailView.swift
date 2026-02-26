//
//  DiaryDetailView.swift
//  innerBloom
//
//  日记详情页 - S-002 (B-012)
//  显示：媒体 + 日记总结 + 标签 + 聊天记录
//  B-017: 多语言支持
//  Style: Cinematic Dark
//

import SwiftUI
import AVKit

struct DiaryDetailView: View {
    
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var showFullChat = false
    @State private var isPlayingVideo = false
    @State private var player: AVPlayer?
    @State private var headerImage: UIImage?
    
    // 注入 ViewModel 以处理标签跳转
    var onTagSelected: ((Tag) -> Void)?
    var onDelete: (() -> Void)?
    
    init(entry: DiaryEntry, onTagSelected: ((Tag) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.entry = entry
        self.onTagSelected = onTagSelected
        self.onDelete = onDelete
        
        let mgr = LocalMediaManager.shared
        var image: UIImage? = nil
        if entry.mediaType != .video {
            if let path = entry.localMediaPath {
                image = mgr.fullImageFromMemory(forPath: path)
            }
            if image == nil, let tp = entry.thumbnailPath {
                image = mgr.fullImageFromMemory(forPath: tp)
            }
        }
        _headerImage = State(initialValue: image)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 背景
            Theme.background.ignoresSafeArea()
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // 1. 媒体展示区 (占主要视觉)
                        mediaHeaderView(height: geometry.size.width * 1.2, screenWidth: geometry.size.width)
                    
                    // 2. 内容区域
                    VStack(alignment: .leading, spacing: 24) {
                        // 日期与时间
                        dateHeaderView
                        
                        // 标签列表
                        // B-017: 支持多语言
                        if !entry.tagIds.isEmpty {
                            // 提示用户标签来源 (如果是 Mock 或特定格式)
                            if entry.tagIds.contains(where: { findTag(byId: $0)?.name.contains("年") ?? false }) {
                                Text(String.localized(.aiGeneratedTags))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                                    .padding(.bottom, -8)
                            }
                            tagsView
                        }
                        
                        // 日记总结 (核心内容)
                        summaryView
                        
                        // 聊天记录回顾 (折叠式)
                        chatHistoryPreview
                        
                        // 底部留白
                        Spacer().frame(height: 50)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            }  // GeometryReader 结束
            
            // 顶部导航栏 (透明背景)
            customNavBar
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showFullChat) {
            chatHistorySheet
        }
        .onAppear {
            setupVideoPlayer()
        }
        .onDisappear {
            player?.pause()
        }
        .task {
            guard headerImage == nil, entry.mediaType != .video else { return }
            
            let mgr = LocalMediaManager.shared
            
            if let path = entry.localMediaPath,
               let img = mgr.cachedFullImage(forPath: path) {
                headerImage = img
                return
            }
            if let thumbPath = entry.thumbnailPath,
               let img = mgr.cachedFullImage(forPath: thumbPath) {
                headerImage = img
                return
            }
            
            let localPath = entry.localMediaPath ?? "DiaryMedia/\(entry.id.uuidString).jpg"
            if let urlStr = entry.cloudMediaURL ?? entry.cloudThumbnailURL {
                headerImage = await mgr.downloadAndCache(from: urlStr, toRelativePath: localPath)
            }
        }
    }
    
    // MARK: - Subviews
    
    /// 媒体头部视图
    private func mediaHeaderView(height: CGFloat, screenWidth: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // 媒体内容
            Group {
                if entry.mediaType == .video, (entry.localMediaPath != nil || entry.cloudMediaURL != nil) {
                    // 视频播放器（本地或雲端 URL）
                    VideoPlayer(player: player)
                        .overlay(
                            // 播放按钮覆盖
                            ZStack {
                                if !isPlayingVideo {
                                    Color.black.opacity(0.3)
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .onTapGesture {
                                toggleVideoPlayback()
                            }
                        )
                } else if let headerImage {
                    Image(uiImage: headerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if entry.localMediaPath != nil || entry.cloudMediaURL != nil || entry.cloudThumbnailURL != nil {
                    Rectangle()
                        .fill(Theme.surface)
                        .overlay(ProgressView().tint(Theme.textSecondary))
                } else {
                    Rectangle()
                        .fill(Theme.surface)
                        .overlay(
                            Image(systemName: entry.mediaType == .video ? "video.slash" : "photo")
                                .font(.largeTitle)
                                .foregroundColor(Theme.textSecondary)
                        )
                }
            }
            .frame(width: screenWidth, height: height)
            .clipped()
            
            // 渐变遮罩 (让底部文字清晰)
            LinearGradient(
                colors: [Theme.background, Theme.background.opacity(0)],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(height: 120)
        }
    }
    
    /// 日期头部
    private var dateHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt.formatted(date: .long, time: .omitted))
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(Theme.textPrimary)
                
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            
            // 更多操作菜单
            // B-017: 支持多语言
            Menu {
                Button(role: .destructive, action: { onDelete?() }) {
                    Label(String.localized(.deleteDiary), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .padding(8)
                    .background(Circle().fill(Theme.surface))
            }
        }
    }
    
    /// 标签展示
    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entry.tagIds, id: \.self) { tagId in
                    if let tag = findTag(byId: tagId) {
                        Button(action: { onTagSelected?(tag) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "number")
                                    .font(.caption2)
                                Text(tag.name)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.surface))
                            .overlay(Capsule().stroke(Theme.textSecondary.opacity(0.2), lineWidth: 0.5))
                            .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }
    
    /// 日记总结
    /// B-017: 支持多语言
    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.displaySummary ?? String.localized(.noContent))
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(6)
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface.opacity(0.5))
        )
    }
    
    /// 聊天记录预览
    /// B-017: 支持多语言
    private var chatHistoryPreview: some View {
        Button(action: { showFullChat = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String.localized(.reviewConversation))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(String.localized(.conversationRecords, args: entry.messages.count))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .disabled(entry.messages.isEmpty)
    }
    
    /// 聊天记录 Sheet
    /// B-017: 支持多语言
    private var chatHistorySheet: some View {
        NavigationStack {
            ChatView(
                messages: entry.messages,
                isAITyping: false,
                readOnly: true,
                onSendMessage: { _ in }
            )
            .navigationTitle(String.localized(.reviewConversation))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String.localized(.close)) { showFullChat = false }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    /// 自定义导航栏
    private var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.3)))
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10) // 移除硬编码的 60，使用正常的 padding，依靠 Safe Area 布局
    }
    
    // MARK: - Helper Methods
    
    /// 设置视频播放器（支援本地路徑或雲端 URL）
    private func setupVideoPlayer() {
        guard entry.mediaType == .video else { return }
        if let path = entry.localMediaPath {
            let url = LocalMediaManager.shared.getDocumentsDirectory().appendingPathComponent(path)
            player = AVPlayer(url: url)
        } else if let urlString = entry.cloudMediaURL, let url = URL(string: urlString) {
            player = AVPlayer(url: url)
        }
    }
    
    /// 切换视频播放状态
    private func toggleVideoPlayback() {
        guard let player = player else { return }
        
        if isPlayingVideo {
            player.pause()
        } else {
            player.play()
        }
        isPlayingVideo.toggle()
    }
    
    /// 查找标签对象
    private func findTag(byId id: UUID) -> Tag? {
        // 这里应该从 ViewModel 获取，暂时简单实现
        // 实际开发中可以通过 environmentObject 或传入 ViewModel 获取
        return HomeViewModel.shared.availableTags.first { $0.id == id }
    }
}
