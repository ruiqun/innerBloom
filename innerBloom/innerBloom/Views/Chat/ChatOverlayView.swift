//
//  ChatOverlayView.swift
//  innerBloom
//
//  聊天覆盖层组件 - F-004
//  B-007: 完善聊天消息区，支持展开/收起
//  B-017: 多语言支持
//  Style: Cinematic, Floating Bubbles, Centered in Image
//

import SwiftUI
import Combine

/// 聊天覆盖层视图 - 显示在媒体预览上的聊天气泡
struct ChatOverlayView: View {
    
    let messages: [ChatMessage]
    var isAITyping: Bool = false
    var suggestedPrompts: [String] = []  // Best Friend Mode: 建议话题
    var onTapToExpand: (() -> Void)? = nil
    var onSelectPrompt: ((String) -> Void)? = nil  // 点击建议话题
    
    /// 显示的最大消息数
    private let maxVisibleMessages = 1
    
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
                VStack(spacing: 4) {
                    CompactTypingIndicator()
                    // B-027: Premium 優先佇列提示
                    if IAPManager.shared.premiumStatus.isPremium {
                        Text(String.localized(.premiumPriorityHint))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent.opacity(0.7))
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // Best Friend Mode: 建议话题（用户卡住时显示）
            if !suggestedPrompts.isEmpty && !isAITyping {
                suggestedPromptsView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: 280)
        .offset(y: 80)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: messages.count)
        .animation(.easeInOut(duration: 0.2), value: isAITyping)
        .animation(.easeInOut(duration: 0.3), value: suggestedPrompts)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapToExpand?()
        }
    }
    
    /// Best Friend Mode: 建议话题视图
    /// B-017: 多语言支持
    private var suggestedPromptsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String.localized(.notSureWhatToSay))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
                .padding(.leading, 4)
            
            FlowLayout(spacing: 6) {
                ForEach(suggestedPrompts.prefix(3), id: \.self) { prompt in
                    Button(action: {
                        onSelectPrompt?(prompt)
                    }) {
                        Text(prompt)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .background(.ultraThinMaterial, in: Capsule())
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2))
            }
        )
    }
    
    /// 展开提示
    /// B-017: 多语言支持
    private var expandHint: some View {
        HStack(spacing: 4) {
            Text(String.localized(.moreMessages, args: messages.count - maxVisibleMessages))
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
            if !isCompact {
                if message.sender == .user { Spacer(minLength: 40) }
            }
            
            Text(message.content)
                .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(isCompact ? 3 : nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, isCompact ? 14 : 16)
                .padding(.vertical, isCompact ? 10 : 12)
                .background(
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                        .fill(bubbleTint(for: message.sender))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                        .stroke(bubbleBorder(for: message.sender), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: isCompact ? 4 : 6, x: 0, y: 2)
            
            if !isCompact {
                if message.sender == .ai { Spacer(minLength: 40) }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func bubbleTint(for sender: ChatSender) -> Color {
        switch sender {
        case .user:
            return Theme.accent.opacity(isCompact ? 0.35 : 0.18)
        case .ai:
            return Color.black.opacity(isCompact ? 0.55 : 0.25)
        }
    }
    
    private func bubbleBorder(for sender: ChatSender) -> Color {
        switch sender {
        case .user:
            return Theme.accent.opacity(isCompact ? 0.4 : 0.6)
        case .ai:
            return Color.white.opacity(isCompact ? 0.15 : 0.3)
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
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.25))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            
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

// MARK: - FlowLayout 组件

/// 自适应流式布局（用于建议话题）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // 换行
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        totalHeight = currentY + lineHeight
        
        return (CGSize(width: totalWidth, height: totalHeight), frames)
    }
}
