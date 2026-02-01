//
//  InputAreaView.swift
//  innerBloom
//
//  输入区组件 - F-002, F-011
//  Style: Glassmorphism-lite, Minimalist
//

import SwiftUI

struct InputAreaView: View {
    
    @Binding var inputText: String
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    
    private let maxCharacters = 500
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入框容器
            HStack(alignment: .bottom, spacing: 16) {
                // 语音按钮 (独立悬浮感)
                Button(action: {
                    if isRecording {
                        onStopRecording()
                    } else {
                        onStartRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.2) : Theme.accent.opacity(0.1))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(isRecording ? Color.red : Theme.accent, lineWidth: 1)
                                    .opacity(0.5)
                            )
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic")
                            .font(.system(size: 20))
                            .foregroundColor(isRecording ? .red : Theme.accent)
                            .neonGlow(color: isRecording ? .red : Theme.accent, radius: 8)
                    }
                }
                .buttonStyle(.plain)
                
                // 文字输入框 (Glassmorphism)
                TextField("", text: $inputText, axis: .vertical)
                    .placeholder(when: inputText.isEmpty) {
                        Text("说说你的心情...")
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1...4)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.glassMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
            }
            
            // 字数统计 (极简)
            if !inputText.isEmpty {
                HStack {
                    Spacer()
                    Text("\(inputText.count)/\(maxCharacters)")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// Helper for placeholder color
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        InputAreaView(
            inputText: .constant(""),
            isRecording: false,
            onStartRecording: {},
            onStopRecording: {}
        )
        .padding()
    }
}
