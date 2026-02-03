//
//  ChatView.swift
//  innerBloom
//
//  完整聊天视图组件 - F-004, D-003
//  B-007: 加入聊天消息区（先假资料）
//  B-017: 多语言支持
//  Style: Cinematic Dark, Floating Bubbles
//

import SwiftUI
import Combine

/// 聊天视图 - 显示完整的聊天记录
struct ChatView: View {
    
    let messages: [ChatMessage]
    let isAITyping: Bool
    let readOnly: Bool
    let onSendMessage: (String) -> Void
    
    init(messages: [ChatMessage], isAITyping: Bool, readOnly: Bool = false, onSendMessage: @escaping (String) -> Void) {
        self.messages = messages
        self.isAITyping = isAITyping
        self.readOnly = readOnly
        self.onSendMessage = onSendMessage
    }
    
    @State private var inputText: String = ""
    @State private var scrollViewProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // 聊天消息列表
            chatMessagesList
            
            // 输入区分隔线
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 快速输入区
            if !readOnly {
                quickInputArea
            }
        }
        .background(Theme.background.opacity(0.95))
    }
    
    // MARK: - 聊天消息列表
    
    private var chatMessagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatMessageRow(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                    
                    // AI 正在输入指示器
                    if isAITyping {
                        TypingIndicator()
                            .id("typing-indicator")
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    
                    // 底部占位，确保最后一条消息不被遮挡
                    Color.clear.frame(height: 8)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onAppear {
                scrollViewProxy = proxy
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isAITyping) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // MARK: - 快速输入区
    // B-017: 支持多语言
    
    private var quickInputArea: some View {
        HStack(spacing: 12) {
            TextField(String.localized(.reply), text: $inputText, prompt: Text(String.localized(.reply)).foregroundColor(Theme.textSecondary.opacity(0.5)), axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1...3)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
            
            // 发送按钮
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.isEmpty ? Theme.textSecondary.opacity(0.3) : Theme.accent)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        onSendMessage(text)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if isAITyping {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            } else {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - 聊天消息行

struct ChatMessageRow: View {
    let message: ChatMessage
    
    @State private var isAppearing = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                // 消息气泡
                messageBubble
                
                // 时间戳
                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            }
            
            if message.sender == .ai {
                Spacer(minLength: 60)
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
    }
    
    private var messageBubble: some View {
        Text(message.content)
            .font(.system(size: 15))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(bubbleBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(bubbleBorder, lineWidth: 0.5)
            )
    }
    
    private var bubbleBackground: Color {
        switch message.sender {
        case .user:
            return Theme.accent.opacity(0.3)
        case .ai:
            return Color.white.opacity(0.08)
        }
    }
    
    private var bubbleBorder: Color {
        switch message.sender {
        case .user:
            return Theme.accent.opacity(0.5)
        case .ai:
            return Color.white.opacity(0.15)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - AI 正在输入指示器

struct TypingIndicator: View {
    @State private var dotIndex = 0
    
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotIndex == index ? 1.2 : 0.8)
                        .opacity(dotIndex == index ? 1 : 0.4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            
            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                dotIndex = (dotIndex + 1) % 3
            }
        }
    }
}

// MARK: - 示例假数据 (B-007)

extension ChatMessage {
    /// 生成示例对话数据
    static let sampleConversation: [ChatMessage] = [
        ChatMessage(
            sender: .ai,
            content: "这张照片拍得很有意境呢，是在哪里拍的？",
            timestamp: Date().addingTimeInterval(-300)
        ),
        ChatMessage(
            sender: .user,
            content: "是在去年秋天的京都，那天刚好下了一点小雨",
            timestamp: Date().addingTimeInterval(-240)
        ),
        ChatMessage(
            sender: .ai,
            content: "雨中的京都一定很美。我能感受到照片里那种宁静的氛围，你当时是什么心情呢？",
            timestamp: Date().addingTimeInterval(-180)
        ),
        ChatMessage(
            sender: .user,
            content: "有一点感伤吧，因为那是和一个好朋友最后一次旅行",
            timestamp: Date().addingTimeInterval(-120)
        ),
        ChatMessage(
            sender: .ai,
            content: "我能理解那种感觉。和重要的人一起的时光总是特别珍贵，即使有些感伤，这些回忆也会成为温暖的记忆。",
            timestamp: Date().addingTimeInterval(-60)
        )
    ]
    
    /// AI 欢迎语
    static func welcomeMessage(for mediaType: MediaType) -> ChatMessage {
        let content: String
        switch mediaType {
        case .photo:
            content = "这张照片看起来很有故事，能跟我说说吗？"
        case .video:
            content = "这段影片记录了什么特别的时刻呢？"
        }
        return ChatMessage(sender: .ai, content: content)
    }
    
    /// AI 继续对话的随机回应
    static let aiResponses: [String] = [
        "我明白了，这真的很特别。",
        "听起来是很难忘的经历呢。",
        "你当时一定有很多感触吧？",
        "这让我想到了很多...",
        "谢谢你跟我分享这些。",
        "能感受到你说的那种心情。",
        "这段回忆对你来说一定很重要。",
        "还有什么想聊的吗？我在听。"
    ]
}

// MARK: - Preview

#Preview("聊天视图") {
    ChatView(
        messages: ChatMessage.sampleConversation,
        isAITyping: false,
        onSendMessage: { _ in }
    )
}

#Preview("AI 正在输入") {
    ChatView(
        messages: [ChatMessage.sampleConversation.first!],
        isAITyping: true,
        onSendMessage: { _ in }
    )
}

#Preview("打字指示器") {
    ZStack {
        Theme.background.ignoresSafeArea()
        TypingIndicator()
            .padding()
    }
}
