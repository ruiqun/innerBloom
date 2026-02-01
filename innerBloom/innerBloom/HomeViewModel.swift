//
//  HomeViewModel.swift
//  innerBloom
//
//  主页视图模型 - 管理 S-001 的状态与逻辑
//

import Foundation
import SwiftUI

/// 主页显示模式
enum HomeMode {
    case browsing   // 浏览模式：查看日记列表
    case creating   // 创建模式：新增日记 + 聊天
}

/// 主页视图模型
/// 使用 @Observable 宏（遵循 .cursorrules）
@Observable
final class HomeViewModel {
    
    // MARK: - 显示模式
    
    /// 当前模式（浏览/创建）
    var currentMode: HomeMode = .browsing
    
    // MARK: - 标签相关 (F-009)
    
    /// 所有可用标签
    var availableTags: [Tag] = [Tag.all]
    
    /// 当前选中的标签
    var selectedTag: Tag = Tag.all
    
    // MARK: - 日记列表 (F-006)
    
    /// 当前标签下的日记列表
    var diaryEntries: [DiaryEntry] = []
    
    /// 是否正在加载
    var isLoading: Bool = false
    
    // MARK: - 创建模式相关
    
    /// 当前正在创建的日记（草稿）
    var currentDraft: DiaryEntry?
    
    /// 选中的媒体图片（临时存储）
    var selectedMediaImage: UIImage?
    
    /// 用户输入的文字
    var userInputText: String = ""
    
    /// 是否正在录音
    var isRecording: Bool = false
    
    /// 当前会话的聊天消息 (D-003)
    var chatMessages: [ChatMessage] = []
    
    // MARK: - 初始化
    
    init() {
        print("[HomeViewModel] Initialized")
        // 初始加载标签
        loadTags()
    }
    
    // MARK: - 标签操作
    
    /// 加载标签列表
    func loadTags() {
        print("[HomeViewModel] Loading tags...")
        // TODO: B-012 从 Supabase 加载标签
        // 目前使用预设标签
        availableTags = [Tag.all]
        selectedTag = Tag.all
        print("[HomeViewModel] Tags loaded: \(availableTags.count)")
    }
    
    /// 选择标签
    func selectTag(_ tag: Tag) {
        print("[HomeViewModel] Selected tag: \(tag.name)")
        selectedTag = tag
        // TODO: B-012 根据标签筛选日记列表
        loadDiariesForCurrentTag()
    }
    
    // MARK: - 日记列表操作
    
    /// 加载当前标签下的日记
    func loadDiariesForCurrentTag() {
        print("[HomeViewModel] Loading diaries for tag: \(selectedTag.name)")
        isLoading = true
        
        // TODO: B-012 从 Supabase 加载日记
        // 目前返回空列表（空状态）
        diaryEntries = []
        
        isLoading = false
        print("[HomeViewModel] Diaries loaded: \(diaryEntries.count)")
    }
    
    // MARK: - 模式切换 (F-010)
    
    /// 切换到创建模式（右→左滑触发）
    func enterCreatingMode() {
        print("[HomeViewModel] Entering creating mode")
        currentMode = .creating
        // 创建新草稿
        currentDraft = nil
        selectedMediaImage = nil
        userInputText = ""
        chatMessages = []
        
        // 模拟 AI 开场白 (可选)
        // simulateAIResponse(delay: 0.5, text: "选一张照片，告诉我发生了什么？")
    }
    
    /// 取消创建，返回浏览模式
    func cancelCreating() {
        print("[HomeViewModel] Canceling creation, back to browsing")
        currentMode = .browsing
        currentDraft = nil
        selectedMediaImage = nil
        userInputText = ""
        chatMessages = []
    }
    
    /// 结束保存 (F-005)
    func finishAndSave() {
        print("[HomeViewModel] Finish and save triggered")
        
        // TODO: B-010 实现完整的保存逻辑
        // 1. 生成 AI 总结
        // 2. 生成标签
        // 3. 保存到 Supabase
        
        // 目前仅切换回浏览模式
        currentMode = .browsing
        currentDraft = nil
        selectedMediaImage = nil
        userInputText = ""
        chatMessages = []
        
        print("[HomeViewModel] Save completed (placeholder)")
    }
    
    // MARK: - 媒体选择 (F-001)
    
    /// 设置选中的媒体
    func setSelectedMedia(image: UIImage) {
        print("[HomeViewModel] Media selected")
        
        // 1. 清除旧状态
        selectedMediaImage = image
        chatMessages = [] // 清空过往对话
        
        // 2. 创建新草稿
        currentDraft = DiaryEntry(mediaType: .photo)
        print("[HomeViewModel] Draft created: \(currentDraft?.id.uuidString ?? "nil")")
        
        // 3. 模拟 AI 分析后的回应
        simulateAIResponse(delay: 1.5, text: "这张照片看起来很有故事，能多跟我说说吗？")
    }
    
    // MARK: - 语音输入 (F-011)
    
    /// 开始录音
    func startRecording() {
        print("[HomeViewModel] Start recording")
        // TODO: B-006 实现语音输入
        isRecording = true
    }
    
    /// 停止录音
    func stopRecording() {
        print("[HomeViewModel] Stop recording")
        // TODO: B-006 实现语音输入
        isRecording = false
        
        // 模拟录音转文字完成
        if !userInputText.isEmpty {
            sendMessage(userInputText)
            userInputText = ""
        }
    }
    
    // MARK: - 聊天逻辑 (F-004)
    
    /// 发送用户消息
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMsg = ChatMessage(sender: .user, content: text)
        chatMessages.append(userMsg)
        print("[HomeViewModel] User sent message: \(text)")
        
        // 模拟 AI 回复
        simulateAIResponse(delay: 1.0, text: "我明白了，这真的很特别。")
    }
    
    /// 模拟 AI 回复
    private func simulateAIResponse(delay: TimeInterval, text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            let aiMsg = ChatMessage(sender: .ai, content: text)
            self?.chatMessages.append(aiMsg)
            print("[HomeViewModel] AI sent message: \(text)")
        }
    }
}
