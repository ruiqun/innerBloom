//
//  TagChipsView.swift
//  innerBloom
//
//  标签图块组件 - F-009
//  Style: Cinematic Dark
//

import SwiftUI

struct TagChipsView: View {
    
    let tags: [Tag]
    let selectedTag: Tag
    let onSelectTag: (Tag) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(tags) { tag in
                    TagChipButton(
                        tag: tag,
                        isSelected: tag.id == selectedTag.id,
                        onTap: {
                            onSelectTag(tag)
                        }
                    )
                }
            }
            .padding(.horizontal, 24) // Match content padding
            .padding(.vertical, 8)
        }
    }
}

struct TagChipButton: View {
    
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let icon = tag.icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                
                Text(tag.name)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.accent.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        TagChipsView(
            tags: Tag.samples,
            selectedTag: Tag.all,
            onSelectTag: { _ in }
        )
    }
}
