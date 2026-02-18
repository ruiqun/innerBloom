//
//  ActionButtonsView.swift
//  innerBloom
//
//  操作按钮组件 - F-005
//  B-017: 多语言支持
//  Style: Cinematic, Gold Accent
//

import SwiftUI

struct ActionButtonsView: View {
    
    let onBack: () -> Void
    let onSaveMemory: () -> Void
    let canSave: Bool
    let isSaving: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // 返回按钮 (chevron.left 图标)
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light)) // Thin/Light weight
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        Circle()
                            .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 0.5) // 极细描边
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            
            Spacer()
            
            // Save Memory 按钮 (Royal Minimal: 仅描边 + 小点缀)
            // B-017: 多语言支持
            Button(action: onSaveMemory) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(Theme.accent)
                    } else {
                        // 线性图标
                        Image(systemName: "heart") // 使用线性图标
                            .font(.system(size: 14, weight: .light))
                        Text(String.localized(.saveMemory))
                            .font(Theme.royalFont(size: 14, weight: .medium)) // Serif 字体
                    }
                }
                .foregroundColor(canSave ? Theme.accent : Theme.textSecondary.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(canSave ? Theme.accent.opacity(0.1) : Color.white.opacity(0.05)) // 极淡的金色填充
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            canSave ? Theme.goldLinearGradient : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        ) // 金色渐变描边
                )
                // 金色小点缀（右上角光点）
                .overlay(
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 4, height: 4)
                        .offset(x: 4, y: -4)
                        .opacity(canSave ? 1 : 0),
                    alignment: .topTrailing
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .scaleEffect(canSave ? 1.0 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSave)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 40) {
            ActionButtonsView(
                onBack: {},
                onSaveMemory: {},
                canSave: true,
                isSaving: false
            )
            
            ActionButtonsView(
                onBack: {},
                onSaveMemory: {},
                canSave: false,
                isSaving: false
            )
            
            ActionButtonsView(
                onBack: {},
                onSaveMemory: {},
                canSave: true,
                isSaving: true
            )
        }
        .padding()
    }
}
