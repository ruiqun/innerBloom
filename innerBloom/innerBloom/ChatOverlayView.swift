//
//  ChatOverlayView.swift
//  innerBloom
//
//  聊天覆盖层组件 - F-004
//  B-007: 完善聊天消息区，支持展开/收起
//  Style: Cinematic, Floating Bubbles, Centered in Image
//

import SwiftUI
import Combine

/// 聊天覆盖层视图 - 显示在媒体预览上的聊天气泡
struct ChatOverlayView: View {
    
    let messages: [ChatMessage]
    var isAITyping: Bool = false
    var onTapToExpand: (() -> Void)? = nil
    
    /// 显示的最大消息数
    private let maxVisibleMessages = 3
    
    var body: some View {
        VStack(spacing: 8) {
            // 显示最近几条消息
            ForEach(Array(messages.suffix(maxVisibleMessages).enumerated()), id: \.element.id) { index, message in
                ChatBubble(message: message, isCompact: true)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
            
            // AI 正在输入指示器
            if isAITyping {
                CompactTypingIndicator()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // 展开提示（当有更多消息时）
            if messages.count > maxVisibleMessages {
                expandHint
            }
        }
        .frame(maxWidth: 260)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: messages.count)
        .animation(.easeInOut(duration: 0.2), value: isAITyping)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapToExpand?()
        }
    }
    
    /// 展开提示
    private var expandHint: some View {
        HStack(spacing: 4) {
            Text("还有 \(messages.count - maxVisibleMessages) 条消息")
                .font(.system(size: 11))
            Image(systemName: "chevron.up")
                .font(.system(size: 10))
        }
        .foregroundColor(Theme.textSecondary.opacity(0.6))
        .padding(.top, 4)
    }
}

/// 聊天气泡 - 支持紧凑模式和普通模式
struct ChatBubble: View {
    
    let message: ChatMessage
    var isCompact: Bool = false
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer(minLength: isCompact ? 20 : 40)
            }
            
            Text(message.content)
                .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(isCompact ? 3 : nil)
                .padding(.horizontal, isCompact ? 14 : 16)
                .padding(.vertical, isCompact ? 10 : 12)
                .background(
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                        .fill(bubbleBackground(for: message.sender))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 16 : 20))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                        .stroke(bubbleBorder(for: message.sender), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: isCompact ? 4 : 6, x: 0, y: 2)
            
            if message.sender == .ai {
                Spacer(minLength: isCompact ? 20 : 40)
            }
        }
    }
    
    private func bubbleBackground(for sender: ChatSender) -> Color {
        switch sender {
        case .user:
            return Theme.accent.opacity(0.4)
        case .ai:
            return Theme.aiBubbleBackground.opacity(0.9)
        }
    }
    
    private func bubbleBorder(for sender: ChatSender) -> Color {
        switch sender {
        case .user:
            return Theme.accent.opacity(0.6)
        case .ai:
            return Color.white.opacity(0.3)
        }
    }
}

/// 紧凑型 AI 输入指示器
struct CompactTypingIndicator: View {
    @State private var dotIndex = 0
    
    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.textSecondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(dotIndex == index ? 1.3 : 0.7)
                        .opacity(dotIndex == index ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.aiBubbleBackground.opacity(0.9))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                dotIndex = (dotIndex + 1) % 3
            }
        }
    }
}

// MARK: - Previews

#Preview("默认状态") {
    ZStack {
        Theme.background.ignoresSafeArea()
        Circle().fill(Color.gray.opacity(0.3)).frame(width: 280)
        
        ChatOverlayView(messages: [
            ChatMessage(sender: .ai, content: "这张照片看起来很有故事。"),
            ChatMessage(sender: .user, content: "是啊，那是很难忘的一天。")
        ])
        .frame(width: 280, height: 280)
    }
}

#Preview("AI 正在输入") {
    ZStack {
        Theme.background.ignoresSafeArea()
        Circle().fill(Color.gray.opacity(0.3)).frame(width: 280)
        
        ChatOverlayView(
            messages: [
                ChatMessage(sender: .ai, content: "这张照片看起来很有故事。")
            ],
            isAITyping: true
        )
        .frame(width: 280, height: 280)
    }
}

#Preview("多条消息") {
    ZStack {
        Theme.background.ignoresSafeArea()
        Circle().fill(Color.gray.opacity(0.3)).frame(width: 280)
        
        ChatOverlayView(messages: ChatMessage.sampleConversation)
            .frame(width: 280, height: 280)
    }
}
