//
//  DiaryEntry.swift
//  innerBloom
//
//  日记条目数据模型 - D-001, D-002, D-005, D-006, D-009, D-003
//  B-003: 添加 Codable 支持，用于本机草稿持久化
//  B-004: 添加云端路径字段与同步状态管理
//

import Foundation

/// 媒体类型
enum MediaType: String, Codable {
    case photo = "photo"
    case video = "video"
}

/// 日记同步状态
enum SyncStatus: String, Codable {
    case local      // 仅本机
    case syncing    // 同步中
    case synced     // 已同步
    case failed     // 同步失败
}

/// 聊天消息发送者
enum ChatSender: String, Codable {
    case user
    case ai
}

/// 聊天消息模型 (D-003)
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: ChatSender
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), sender: ChatSender, content: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
    }
}

/// 日记条目模型
/// 对应 D-001：日记清单
/// Codable 支持本机草稿持久化 (B-003)
struct DiaryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - 媒体相关 (D-001, B-004)
    var mediaType: MediaType
    var localMediaPath: String?       // 本机媒体路径（相对路径）
    var cloudMediaPath: String?       // 云端媒体路径（Supabase Storage bucket/path）
    var cloudMediaURL: String?        // 云端媒体公开 URL
    var thumbnailPath: String?        // 本机缩图路径（相对路径）
    var cloudThumbnailPath: String?   // 云端缩图路径
    var cloudThumbnailURL: String?    // 云端缩图公开 URL
    
    // MARK: - 使用者输入 (D-002)
    var userInputText: String?   // 使用者输入的文字/语音转文字
    
    // MARK: - 标题 (New)
    var title: String?
    
    // MARK: - 风格 (New)
    var style: String?
    
    // MARK: - 聊天记录 (D-003)
    var messages: [ChatMessage] = []
    
    // MARK: - AI 生成内容 (D-004, D-005)
    var aiAnalysisResult: String?  // AI 对媒体的分析结果
    var diarySummary: String?      // AI 生成的日记总结（使用者口吻）
    
    // MARK: - 标签 (D-009)
    var tagIds: [UUID]  // 关联的标签 ID 列表
    
    // MARK: - 状态 (D-006)
    var isAnalyzed: Bool        // 是否已分析
    var isSummarized: Bool      // 是否已生成总结
    var isSaved: Bool           // 是否保存完成
    var syncStatus: SyncStatus  // 云端同步状态
    var lastErrorMessage: String?
    
    // MARK: - 初始化
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        mediaType: MediaType,
        localMediaPath: String? = nil,
        thumbnailPath: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.mediaType = mediaType
        self.localMediaPath = localMediaPath
        self.cloudMediaPath = nil
        self.cloudMediaURL = nil
        self.thumbnailPath = thumbnailPath
        self.cloudThumbnailPath = nil
        self.cloudThumbnailURL = nil
        self.userInputText = nil
        self.title = nil
        self.style = nil
        self.messages = []
        self.aiAnalysisResult = nil
        self.diarySummary = nil
        self.tagIds = []
        self.isAnalyzed = false
        self.isSummarized = false
        self.isSaved = false
        self.syncStatus = .local
        self.lastErrorMessage = nil
        
        // Debug: 日记创建日志
        print("[DiaryEntry] Created new entry: \(id), type: \(mediaType.rawValue)")
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt
        case mediaType, localMediaPath, cloudMediaPath, cloudMediaURL
        case thumbnailPath, cloudThumbnailPath, cloudThumbnailURL
        case userInputText, messages
        case title, style
        case aiAnalysisResult, diarySummary
        case tagIds
        case isAnalyzed, isSummarized, isSaved, syncStatus, lastErrorMessage
    }
    
    // MARK: - 更新时间
    
    /// 更新修改时间
    mutating func touch() {
        updatedAt = Date()
    }
    
    // MARK: - 云端同步 (B-004)
    
    /// 更新云端媒体信息
    mutating func updateCloudMedia(path: String, url: URL?) {
        cloudMediaPath = path
        cloudMediaURL = url?.absoluteString
        touch()
    }
    
    /// 更新云端缩略图信息
    mutating func updateCloudThumbnail(path: String, url: URL?) {
        cloudThumbnailPath = path
        cloudThumbnailURL = url?.absoluteString
        touch()
    }
    
    /// 标记同步状态
    mutating func markSyncing() {
        syncStatus = .syncing
        lastErrorMessage = nil
        touch()
    }
    
    /// 标记同步成功
    mutating func markSynced() {
        syncStatus = .synced
        lastErrorMessage = nil
        touch()
    }
    
    /// 标记同步失败
    mutating func markSyncFailed(_ error: String) {
        syncStatus = .failed
        lastErrorMessage = error
        touch()
    }
}

// MARK: - 计算属性

extension DiaryEntry {
    /// 获取显示用的摘要文字（优先显示总结，否则显示用户输入）
    var displaySummary: String? {
        diarySummary ?? userInputText
    }
    
    /// 判断是否为草稿状态
    var isDraft: Bool {
        !isSaved
    }
    
    /// 判断媒体是否可用
    var hasMedia: Bool {
        localMediaPath != nil || cloudMediaPath != nil
    }
}

// MARK: - 示例数据（仅用于 Preview）

extension DiaryEntry {
    static let sample = DiaryEntry(
        mediaType: .photo,
        localMediaPath: nil
    )
    
    static let samples: [DiaryEntry] = []  // 空列表，用于空状态展示
}
