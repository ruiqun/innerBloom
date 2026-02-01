//
//  DiaryEntry.swift
//  innerBloom
//
//  日记条目数据模型 - D-001, D-002, D-005, D-006, D-009
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

/// 日记条目模型
/// 对应 D-001：日记清单
struct DiaryEntry: Identifiable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - 媒体相关 (D-001)
    var mediaType: MediaType
    var localMediaPath: String?  // 本机媒体路径
    var cloudMediaPath: String?  // 云端媒体路径（Supabase Storage）
    var thumbnailPath: String?   // 缩图路径
    
    // MARK: - 使用者输入 (D-002)
    var userInputText: String?   // 使用者输入的文字/语音转文字
    
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
        localMediaPath: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.mediaType = mediaType
        self.localMediaPath = localMediaPath
        self.cloudMediaPath = nil
        self.thumbnailPath = nil
        self.userInputText = nil
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
