//
//  ActionButtonsView.swift
//  innerBloom
//
//  操作按钮组件 - F-005
//  Style: Cinematic, Emerald Accent
//

import SwiftUI

struct ActionButtonsView: View {
    
    let onCancel: () -> Void
    let onFinishSave: () -> Void
    let canSave: Bool
    let isSaving: Bool
    
    var body: some View {
        HStack(spacing: 24) {
            // 取消按钮 (极简文字，低调)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            
            Spacer()
            
            // 结束保存按钮 (强调色 + 柔光 + 同心圆环)
            Button(action: onFinishSave) {
                ZStack {
                    // 外发光晕
                    if canSave {
                        Circle()
                            .fill(Theme.accent.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .blur(radius: 10)
                    }
                    
                    // 同心圆环装饰
                    Circle()
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                        .frame(width: 64, height: 64)
                        .scaleEffect(isSaving ? 1.1 : 1.0)
                        .opacity(isSaving ? 0 : 1)
                        .animation(isSaving ? .easeOut(duration: 1).repeatForever(autoreverses: false) : .default, value: isSaving)
                    
                    // 主按钮实体
                    Circle()
                        .fill(canSave ? Theme.accent : Color.white.opacity(0.1))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(canSave ? .black : Theme.textSecondary)
                                }
                            }
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .scaleEffect(canSave ? 1.0 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSave)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ActionButtonsView(
            onCancel: {},
            onFinishSave: {},
            canSave: true,
            isSaving: false
        )
        .padding()
    }
}
