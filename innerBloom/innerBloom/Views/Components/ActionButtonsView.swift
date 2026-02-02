//
//  ActionButtonsView.swift
//  innerBloom
//
//  操作按钮组件 - F-005
//  Style: Cinematic, Emerald Accent
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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            
            Spacer()
            
            // Save Memory 按钮 (强调色胶囊按钮)
            Button(action: onSaveMemory) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.black)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Save Memory")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(canSave ? .black : Theme.textSecondary.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(canSave ? Theme.accent : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(canSave ? Theme.accent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
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
