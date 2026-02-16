//
//  DiaryListView.swift
//  innerBloom
//
//  日记列表组件 - F-006
//  B-015: 添加同步失败重试支持
//  B-017: 多语言支持
//  B-020: 无限滚动分页支持
//  Style: Cinematic Dark
//

import SwiftUI

struct DiaryListView: View {
    
    let entries: [DiaryEntry]
    let currentTagName: String
    let isLoading: Bool
    let onTapEntry: (DiaryEntry) -> Void
    let onRetry: ((DiaryEntry) -> Void)?  // B-015: 重试回调
    let onEntryAppear: ((DiaryEntry) -> Void)?  // B-020: 无限滚动触发
    let isLoadingMore: Bool  // B-020: 是否正在加载更多
    let hasMoreData: Bool    // B-020: 是否还有更多数据
    
    init(
        entries: [DiaryEntry],
        currentTagName: String,
        isLoading: Bool,
        onTapEntry: @escaping (DiaryEntry) -> Void,
        onRetry: ((DiaryEntry) -> Void)? = nil,
        onEntryAppear: ((DiaryEntry) -> Void)? = nil,
        isLoadingMore: Bool = false,
        hasMoreData: Bool = true
    ) {
        self.entries = entries
        self.currentTagName = currentTagName
        self.isLoading = isLoading
        self.onTapEntry = onTapEntry
        self.onRetry = onRetry
        self.onEntryAppear = onEntryAppear
        self.isLoadingMore = isLoadingMore
        self.hasMoreData = hasMoreData
    }
    
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
    
    /// B-017: 支持多语言；字体与列表风格协调
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.textSecondary)
            Text(String.localized(.loading))
                .font(Theme.listAuxiliaryFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// B-017: 支持多语言
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary.opacity(0.3))
            
            if currentTagName == String.localized(.all) || currentTagName == "全部" {
                Text(String.localized(.noDiaryYet))
                    .font(Theme.titleFont())
                    .foregroundColor(Theme.textSecondary)
                
                Text(String.localized(.swipeLeftToCreate))
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                Text("「\(currentTagName)」")
                    .font(Theme.titleFont())
                    .foregroundColor(Theme.textSecondary)
                
                Text(String.localized(.noDiaryInCategory))
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var diaryListContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(entries) { entry in
                DiaryListItemView(
                    entry: entry,
                    onRetry: onRetry  // B-015: 传递重试回调
                )
                .onTapGesture {
                    // 处理中的条目不允许点击进入
                    guard !entry.processingState.isProcessing else { return }
                    onTapEntry(entry)
                }
                .onAppear {
                    // B-020: 无限滚动 — 当条目出现时通知 ViewModel
                    onEntryAppear?(entry)
                }
            }
            
            // B-020: 加载更多指示器
            if isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.textSecondary)
                        .scaleEffect(0.8)
                    Text(String.localized(.loadingMore))
                        .font(Theme.listAuxiliaryFont())
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if !hasMoreData && !entries.isEmpty {
                Text(String.localized(.noMoreData))
                    .font(Theme.listAuxiliaryFont())
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct DiaryListItemView: View {
    
    let entry: DiaryEntry
    let onRetry: ((DiaryEntry) -> Void)?  // B-015: 重试回调
    
    init(entry: DiaryEntry, onRetry: ((DiaryEntry) -> Void)? = nil) {
        self.entry = entry
        self.onRetry = onRetry
    }
    
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
            
            // B-015: 失败状态遮罩（带重试按钮）
            if isFailed && !isProcessing {
                failedOverlay
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
                    .font(Theme.listAuxiliaryFont())
                    .foregroundColor(Theme.textSecondary)
                
                // 日记总结（与 InnerBloom 标题同字体与大小）
                if let summary = entry.displaySummary {
                    Text(summary)
                        .font(Theme.titleFont())
                        .tracking(Theme.titleTracking)
                        .lineLimit(2)
                        .foregroundColor(Theme.textPrimary)
                } else if isProcessing {
                    // 处理中显示占位
                    Text(String.localized(.generatingSummary))
                        .font(Theme.titleFont())
                        .tracking(Theme.titleTracking)
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .lineLimit(2)
                } else {
                    Text(String.localized(.noContent))
                        .font(.system(size: 14, weight: .regular, design: .serif))
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
                    .font(Theme.listAuxiliaryFont())
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
    
    /// B-015: 失败状态遮罩（带重试按钮）
    /// B-017: 支持多语言
    private var failedOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.5))
            .overlay(
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        
                        Text(String.localized(.syncFailed))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    if let errorMessage = entry.lastErrorMessage {
                        Text(errorMessage)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    // 重试按钮
                    if onRetry != nil {
                        Button(action: {
                            onRetry?(entry)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                Text(String.localized(.retry))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Theme.accent)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            )
    }
    
    /// 处理状态文字
    /// B-017: 支持多语言
    private var processingStateText: String {
        switch entry.processingState {
        case .processing:
            return String.localized(.processing)
        case .aiGenerating:
            return String.localized(.aiGenerating)
        case .uploading:
            return String.localized(.uploading)
        default:
            return String.localized(.processing)
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
