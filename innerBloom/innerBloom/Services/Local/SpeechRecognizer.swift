//
//  SpeechRecognizer.swift
//  innerBloom
//
//  语音识别管理器 - F-011
//  使用 Apple Speech Framework 实现语音转文字
//  B-006: 实现语音输入功能
//

import Foundation
import Speech
import AVFoundation

/// 语音识别状态
enum SpeechRecognizerStatus {
    case idle           // 空闲
    case recording      // 录音中
    case processing     // 处理中
    case error          // 错误
}

/// 语音识别错误
enum SpeechRecognizerError: LocalizedError {
    case notAuthorized
    case notAvailable
    case audioSessionFailed
    case recognitionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "需要麦克风和语音识别权限才能使用语音输入"
        case .notAvailable:
            return "语音识别服务当前不可用"
        case .audioSessionFailed:
            return "无法启动音频会话"
        case .recognitionFailed(let message):
            return "语音识别失败：\(message)"
        }
    }
}

/// 语音识别管理器
/// 使用 @Observable 宏
@Observable
final class SpeechRecognizer {
    
    // MARK: - Singleton
    
    static let shared = SpeechRecognizer()
    
    // MARK: - Properties
    
    /// 当前状态
    private(set) var status: SpeechRecognizerStatus = .idle
    
    /// 是否正在录音
    var isRecording: Bool {
        return status == .recording
    }
    
    /// 实时转写文字（录音过程中持续更新）
    private(set) var transcribedText: String = ""
    
    /// 最终识别结果
    private(set) var finalResult: String = ""
    
    /// 音频电平（用于显示波形动画）
    private(set) var audioLevel: Float = 0.0
    
    /// 错误消息
    private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    /// 识别完成回调
    private var onRecognitionComplete: ((String) -> Void)?
    
    /// 实时更新回调
    private var onTranscriptionUpdate: ((String) -> Void)?
    
    /// 错误回调
    private var onError: ((SpeechRecognizerError) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // 初始化中文语音识别器
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        print("[SpeechRecognizer] Initialized with locale: zh-CN")
    }
    
    // MARK: - Authorization
    
    /// 检查并请求权限
    func requestAuthorization() async -> Bool {
        // 1. 检查语音识别权限
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            await MainActor.run {
                errorMessage = "语音识别权限未授权"
            }
            print("[SpeechRecognizer] Speech recognition not authorized: \(speechStatus)")
            return false
        }
        
        // 2. 检查麦克风权限
        let micStatus = await AVAudioApplication.requestRecordPermission()
        
        guard micStatus else {
            await MainActor.run {
                errorMessage = "麦克风权限未授权"
            }
            print("[SpeechRecognizer] Microphone not authorized")
            return false
        }
        
        print("[SpeechRecognizer] All permissions authorized")
        return true
    }
    
    /// 检查权限状态（不请求）
    func checkAuthorizationStatus() -> (speech: SFSpeechRecognizerAuthorizationStatus, mic: Bool) {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission == .granted
        return (speechStatus, micStatus)
    }
    
    // MARK: - Recording Control
    
    /// 开始录音和识别
    /// - Parameters:
    ///   - onUpdate: 实时转写更新回调
    ///   - onComplete: 识别完成回调
    ///   - onError: 错误回调
    @MainActor
    func startRecording(
        onUpdate: ((String) -> Void)? = nil,
        onComplete: ((String) -> Void)? = nil,
        onError: ((SpeechRecognizerError) -> Void)? = nil
    ) async {
        // 检查状态
        guard status != .recording else {
            print("[SpeechRecognizer] Already recording")
            return
        }
        
        // 保存回调
        self.onTranscriptionUpdate = onUpdate
        self.onRecognitionComplete = onComplete
        self.onError = onError
        
        // 清除之前的状态
        transcribedText = ""
        finalResult = ""
        errorMessage = nil
        
        // 检查权限
        let authorized = await requestAuthorization()
        guard authorized else {
            status = .error
            onError?(.notAuthorized)
            return
        }
        
        // 检查识别器可用性
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            status = .error
            errorMessage = "语音识别服务不可用"
            onError?(.notAvailable)
            print("[SpeechRecognizer] Speech recognizer not available")
            return
        }
        
        // 开始录音
        do {
            try await startRecordingInternal()
            status = .recording
            print("[SpeechRecognizer] Recording started")
        } catch {
            status = .error
            errorMessage = error.localizedDescription
            onError?(.audioSessionFailed)
            print("[SpeechRecognizer] Failed to start recording: \(error)")
        }
    }
    
    /// 停止录音
    @MainActor
    func stopRecording() {
        guard status == .recording else {
            print("[SpeechRecognizer] Not recording, nothing to stop")
            return
        }
        
        status = .processing
        print("[SpeechRecognizer] Stopping recording...")
        
        // 1. 先结束识别请求（让它知道音频结束了）
        recognitionRequest?.endAudio()
        
        // 2. 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 3. 清理识别请求
        recognitionRequest = nil
        
        // 使用最终结果
        finalResult = transcribedText
        
        // 等待一小段时间让最后的识别完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            // 取消任务
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            
            // 4. 停用音频会话（关键：防止 Simulator 音频设备错误）
            self.deactivateAudioSession()
            
            // 回调最终结果
            let result = self.finalResult.isEmpty ? self.transcribedText : self.finalResult
            if !result.isEmpty {
                self.onRecognitionComplete?(result)
            }
            
            self.status = .idle
            self.audioLevel = 0.0
            print("[SpeechRecognizer] Recording stopped, result: \(result)")
        }
    }
    
    /// 取消录音（不返回结果）
    @MainActor
    func cancelRecording() {
        guard status == .recording || status == .processing else { return }
        
        print("[SpeechRecognizer] Canceling recording")
        
        // 1. 结束识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 2. 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 3. 取消识别任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 4. 停用音频会话
        deactivateAudioSession()
        
        // 清除状态
        status = .idle
        transcribedText = ""
        finalResult = ""
        audioLevel = 0.0
    }
    
    /// 停用音频会话（防止 Simulator 音频设备错误）
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("[SpeechRecognizer] Audio session deactivated")
        } catch {
            // 在 Simulator 中可能会失败，忽略错误
            print("[SpeechRecognizer] Audio session deactivation ignored: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// 内部启动录音逻辑
    private func startRecordingInternal() async throws {
        // 取消之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognizerError.audioSessionFailed
        }
        
        // 配置请求
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        
        // 获取输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 安装音频 tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // 计算音频电平
            self?.calculateAudioLevel(from: buffer)
        }
        
        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        // 启动识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                // 更新转写文字
                let text = result.bestTranscription.formattedString
                
                DispatchQueue.main.async {
                    self.transcribedText = text
                    self.onTranscriptionUpdate?(text)
                    
                    // 如果是最终结果
                    if result.isFinal {
                        self.finalResult = text
                        print("[SpeechRecognizer] Final result: \(text)")
                    }
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    // 忽略取消错误
                    if (error as NSError).code != 216 && (error as NSError).code != 1 {
                        self.errorMessage = error.localizedDescription
                        self.onError?(.recognitionFailed(error.localizedDescription))
                        print("[SpeechRecognizer] Recognition error: \(error)")
                    }
                }
            }
        }
    }
    
    /// 计算音频电平
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        var sum: Float = 0
        for i in 0..<Int(frames) {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frames)
        let level = min(max(average * 10, 0), 1) // 归一化到 0-1
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
        }
    }
    
    // MARK: - Cleanup
    
    /// 清理资源
    @MainActor
    func cleanup() {
        cancelRecording()
    }
}
