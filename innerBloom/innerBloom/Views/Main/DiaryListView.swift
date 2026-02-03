//
//  DiaryListView.swift
//  innerBloom
//
//  日记列表组件 - F-006
//  Style: Cinematic Dark
//

import SwiftUI

struct DiaryListView: View {
    
    let entries: [DiaryEntry]
    let currentTagName: String
    let isLoading: Bool
    let onTapEntry: (DiaryEntry) -> Void
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if entries.isEmpty {
                emptyStateView
            } else {
                diaryListContent
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.textSecondary)
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary.opacity(0.3))
            
            if currentTagName == "全部" {
                Text("目前还没有日记")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
                
                Text("向左滑动开始记录你的第一篇日记")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                Text("「\(currentTagName)」还没有日记")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
                
                Text("这个分类还没有日记")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var diaryListContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(entries) { entry in
                DiaryListItemView(entry: entry)
                    .onTapGesture {
                        // 处理中的条目不允许点击进入
                        guard !entry.processingState.isProcessing else { return }
                        onTapEntry(entry)
                    }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct DiaryListItemView: View {
    
    let entry: DiaryEntry
    
    /// 是否正在处理中
    private var isProcessing: Bool {
        entry.processingState.isProcessing
    }
    
    /// 是否处理失败（可重试）
    private var isFailed: Bool {
        entry.processingState == .failed || entry.syncStatus == .failed
    }
    
    var body: some View {
        ZStack {
            // 主内容
            mainContent
            
            // 处理中遮罩
            if isProcessing {
                processingOverlay
            }
            
            // 失败状态指示器
            if isFailed && !isProcessing {
                failedIndicator
            }
        }
    }
    
    private var mainContent: some View {
        HStack(spacing: 16) {
            // 缩图区域
            thumbnailView
            
            // 内容区域
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                if let title = entry.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                } else if isProcessing {
                    // 处理中显示占位标题
                    Text("正在生成标题...")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .lineLimit(1)
                }
                
                if let summary = entry.displaySummary {
                    Text(summary)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(entry.title == nil ? Theme.textPrimary : Theme.textSecondary)
                } else if isProcessing {
                    // 处理中显示占位摘要
                    Text("AI 正在为你生成日记摘要...")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                        .lineLimit(2)
                } else {
                    Text("无内容")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            if isProcessing {
                // 处理中显示加载指示器
                ProgressView()
                    .tint(Theme.accent)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isProcessing ? Theme.accent.opacity(0.3) : Color.white.opacity(0.05), lineWidth: isProcessing ? 1 : 0.5)
        )
        .opacity(isProcessing ? 0.8 : 1.0)
    }
    
    /// 处理中遮罩
    private var processingOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.3))
            .overlay(
                VStack(spacing: 8) {
                    Text(processingStateText)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Theme.accent.opacity(0.8))
                        )
                }
            )
            .allowsHitTesting(false)
    }
    
    /// 失败状态指示器
    private var failedIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(8)
            }
            Spacer()
        }
    }
    
    /// 处理状态文字
    private var processingStateText: String {
        switch entry.processingState {
        case .processing:
            return "处理中..."
        case .aiGenerating:
            return "AI 生成中..."
        case .uploading:
            return "上传中..."
        default:
            return "处理中..."
        }
    }
    
    private var thumbnailView: some View {
        ZStack {
            if let image = loadThumbnail() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: entry.mediaType == .photo ? "photo" : "video")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                    )
            }
        }
    }
    
    private func loadThumbnail() -> UIImage? {
        // 1. 尝试加载本地缩略图
        if let thumbPath = entry.thumbnailPath {
            let fullPath = LocalMediaManager.shared.getDocumentsDirectory().appendingPathComponent(thumbPath).path
            if let image = UIImage(contentsOfFile: fullPath) {
                return image
            }
        }
        
        // 2. 尝试加载本地原图
        if let path = entry.localMediaPath {
            let fullPath = LocalMediaManager.shared.getDocumentsDirectory().appendingPathComponent(path).path
            if let image = UIImage(contentsOfFile: fullPath) {
                return image
            }
        }
        
        return nil
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        DiaryListView(
            entries: [],
            currentTagName: "全部",
            isLoading: false,
            onTapEntry: { _ in }
        )
    }
}
