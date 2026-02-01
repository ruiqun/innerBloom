//
//  ChatOverlayView.swift
//  innerBloom
//
//  聊天覆盖层组件 - F-004
//  Style: Cinematic, Floating Bubbles, Centered in Image
//

import SwiftUI

struct ChatOverlayView: View {
    
    let messages: [ChatMessage]
    
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            
            // 仅显示最近的几条消息，避免遮挡
            ForEach(messages.suffix(2)) { message in
                ChatBubble(message: message)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.bottom, 40) // 在图片内部稍微偏上一点，或居中
        .frame(maxWidth: 240) // 限制宽度，确保在图片圆圈内
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: messages.count)
    }
}

struct ChatBubble: View {
    
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }
            
            Text(message.content)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(bubbleBackground(for: message.sender))
                        // 增加背景模糊，确保在图片上清晰可读
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(bubbleBorder(for: message.sender), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            if message.sender == .ai {
                Spacer()
            }
        }
    }
    
    private func bubbleBackground(for sender: ChatSender) -> Color {
        switch sender {
        case .user:
            return Theme.accent.opacity(0.3) // 用户：强调色半透明，加深一点
        case .ai:
            return Theme.aiBubbleBackground.opacity(0.8) // AI：深色半透明，加深以提高对比度
        }
    }
    
    private func bubbleBorder(for sender: ChatSender) -> Color {
        switch sender {
        case .user:
            return Theme.accent.opacity(0.5)
        case .ai:
            return Color.white.opacity(0.2)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        // 模拟背景图
        Circle().fill(Color.gray).frame(width: 280)
        
        ChatOverlayView(messages: [
            ChatMessage(sender: .ai, content: "这张照片看起来很有故事。"),
            ChatMessage(sender: .user, content: "是啊，那是很难忘的一天。")
        ])
        .frame(width: 280, height: 280)
    }
}
