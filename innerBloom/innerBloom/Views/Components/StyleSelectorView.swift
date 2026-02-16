//
//  StyleSelectorView.swift
//  innerBloom
//
//  日记风格选择器组件
//  Style: Cinematic Dark
//

import SwiftUI

struct StyleSelectorView: View {
    
    @Binding var selectedStyle: DiaryStyle
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(DiaryStyle.allCases, id: \.self) { style in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedStyle = style
                    }
                }) {
                    Text(style.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectedStyle == style ? Color(red: 0.08, green: 0.07, blue: 0.04) : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedStyle == style ? Theme.accent : Color.white.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedStyle == style ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.glassMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        StyleSelectorView(selectedStyle: .constant(.warm))
    }
}
