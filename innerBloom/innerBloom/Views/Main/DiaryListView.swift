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
                        onTapEntry(entry)
                    }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct DiaryListItemView: View {
    
    let entry: DiaryEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // 缩图区域
            thumbnailView
            
            // 内容区域
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                if let summary = entry.displaySummary {
                    Text(summary)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(Theme.textPrimary)
                } else {
                    Text("无内容")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }
    
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
            
            Image(systemName: entry.mediaType == .photo ? "photo" : "video")
                .font(.title3)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(width: 56, height: 56)
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
