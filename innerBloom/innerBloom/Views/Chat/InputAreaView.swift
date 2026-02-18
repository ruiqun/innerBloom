//
//  InputAreaView.swift
//  innerBloom
//
//  输入区组件 - F-002, F-011
//  Style: Glassmorphism-lite, Minimalist
//  B-006: 实现语音输入功能，添加录音状态反馈和波形动画
//  B-017: 多语言支持
//

import SwiftUI

struct InputAreaView: View {
    
    @Binding var inputText: String
    let isRecording: Bool
    var audioLevel: Float = 0.0
    var transcribingText: String = ""
    var isSending: Bool = false
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    var onSend: (() -> Void)? = nil  // 发送消息回调
    
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxCharacters = 500
    
    /// 是否可以发送（有文字或正在录音）
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRecording && !isSending
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 录音状态提示
            if isRecording {
                recordingIndicator
                    .transition(.opacity.combined(with: .scale))
            }
            
            // 输入框容器
            HStack(alignment: .center, spacing: 12) {
                // 语音按钮 (独立悬浮感)
                voiceButton
                
                // 文字输入框 (Glassmorphism)
                textInputField
                
                // 发送按钮
                sendButton
            }
            
            // 字数统计 (极简) - 键盘弹出时显示
            if !inputText.isEmpty && !isRecording && isTextFieldFocused {
                HStack {
                    Spacer()
                    Text("\(inputText.count)/\(maxCharacters)")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: isTextFieldFocused)
    }
    
    // MARK: - 录音状态指示器
    
    private var recordingIndicator: some View {
        HStack(spacing: 12) {
            // 录音波形动画
            WaveformView(audioLevel: audioLevel, isAnimating: isRecording)
                .frame(width: 60, height: 24)
            
            // 实时转写文字或提示
            // B-017: 多语言支持
            Text(transcribingText.isEmpty ? String.localized(.listening) : transcribingText)
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // 录音时长指示（可选）
            RecordingDurationView()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - 语音按钮
    
    private var voiceButton: some View {
        Button(action: {
            // 触觉反馈
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            if isRecording {
                onStopRecording()
            } else {
                onStartRecording()
            }
        }) {
            ZStack {
                // 外圈 - 极简线条
                Circle()
                    .stroke(isRecording ? Color.red.opacity(0.5) : Theme.textSecondary.opacity(0.3), lineWidth: 1)
                    .background(Circle().fill(Color.black.opacity(0.2))) // 深色底增强对比
                    .frame(width: 48, height: 48)
                
                // 图标 - 线性风格 (Thin stroke)
                Image(systemName: isRecording ? "stop.fill" : "mic")
                    .font(.system(size: 20, weight: .light)) // Thin/Light weight
                    .foregroundColor(isRecording ? .red : Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        // B-017: 多语言无障碍支持
        .accessibilityLabel(isRecording ? String.localized(.stopRecording) : String.localized(.startVoiceInput))
        .accessibilityHint(isRecording ? String.localized(.tapToStopRecording) : String.localized(.tapToStartVoice))
    }
    
    // MARK: - 文字输入框
    
    // B-017: 多语言支持
    private var textInputField: some View {
        TextField("", text: $inputText, axis: .vertical)
            .placeholder(when: inputText.isEmpty && !isRecording) {
                Text(String.localized(.shareYourMood))
                    .font(Theme.royalFont(size: 14, weight: .regular)) // Serif 字体
                    .foregroundColor(Theme.textSecondary.opacity(0.4)) // 低对比度 Placeholder
            }
            .placeholder(when: inputText.isEmpty && isRecording) {
                Text(String.localized(.listening))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.red.opacity(0.6))
            }
            .font(.system(size: 14, weight: .regular))
            .textFieldStyle(.plain)
            .foregroundColor(Theme.textPrimary)
            .focused($isTextFieldFocused)
            .lineLimit(1...4)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3)) // 深色玻璃卡片感
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                isTextFieldFocused ? Theme.goldLinearGradient : // 聚焦时金色渐变描边
                                    LinearGradient(colors: [Theme.textSecondary.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                                lineWidth: isTextFieldFocused ? 1 : 0.5
                            )
                    )
                    .shadow(color: isTextFieldFocused ? Theme.accent.opacity(0.2) : Color.clear, radius: 8) // 聚焦微光
            )
            .disabled(isRecording) // 录音时禁用手动输入
            .onSubmit {
                if canSend {
                    onSend?()
                }
            }
    }
    
    // MARK: - 发送按钮
    
    private var sendButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onSend?()
        }) {
            ZStack {
                // 线性风格
                Circle()
                    .stroke(canSend ? Theme.accent : Theme.textSecondary.opacity(0.2), lineWidth: 1)
                    .background(Circle().fill(canSend ? Theme.accent.opacity(0.1) : Color.clear))
                    .frame(width: 40, height: 40)
                
                if isSending {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Theme.accent)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .light)) // Thin weight
                        .foregroundColor(canSend ? Theme.accent : Theme.textSecondary.opacity(0.3))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .scaleEffect(canSend ? 1.0 : 0.9)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: canSend)
    }
}

// MARK: - 波形动画视图

struct WaveformView: View {
    let audioLevel: Float
    let isAnimating: Bool
    
    @State private var phase: CGFloat = 0
    
    private let barCount = 5
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    height: barHeight(for: index),
                    isAnimating: isAnimating
                )
            }
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 24
        let levelFactor = CGFloat(audioLevel)
        
        // 根据音频电平和位置计算高度
        let positionFactor = sin(CGFloat(index) * 0.8 + phase)
        let height = baseHeight + (maxHeight - baseHeight) * levelFactor * (0.5 + 0.5 * positionFactor)
        
        return max(baseHeight, min(maxHeight, height))
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let isAnimating: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.red.opacity(0.8))
            .frame(width: 4, height: height)
            .animation(.easeInOut(duration: 0.1), value: height)
    }
}

// MARK: - 录音时长视图

struct RecordingDurationView: View {
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        Text(formatDuration(duration))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(Color.red)
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }
    
    private func startTimer() {
        duration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            duration += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration) % 60
        let minutes = Int(duration) / 60
        return String(format: "%d:%02d", minutes, seconds)
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

// MARK: - Previews

#Preview("默认状态") {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            InputAreaView(
                inputText: .constant(""),
                isRecording: false,
                audioLevel: 0,
                transcribingText: "",
                isSending: false,
                onStartRecording: {},
                onStopRecording: {},
                onSend: {}
            )
            .padding()
        }
    }
}

#Preview("有文字") {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            InputAreaView(
                inputText: .constant("今天天气真好"),
                isRecording: false,
                audioLevel: 0,
                transcribingText: "",
                isSending: false,
                onStartRecording: {},
                onStopRecording: {},
                onSend: {}
            )
            .padding()
        }
    }
}

#Preview("录音中") {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            InputAreaView(
                inputText: .constant("今天去了海边"),
                isRecording: true,
                audioLevel: 0.5,
                transcribingText: "今天去了海边",
                isSending: false,
                onStartRecording: {},
                onStopRecording: {},
                onSend: {}
            )
            .padding()
        }
    }
}
