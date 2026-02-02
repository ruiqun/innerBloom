//
//  SupabaseDatabaseService.swift
//  innerBloom
//
//  Supabase Database 服务 - B-005, F-012
//  负责：日记数据的 CRUD 操作、云端同步
//

import Foundation

/// Database 服务错误
enum DatabaseServiceError: LocalizedError, Equatable {
    case notConfigured
    case invalidURL
    case requestFailed(statusCode: Int)
    case networkError(String)
    case decodingError(String)
    case encodingError
    case notFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase 未配置"
        case .invalidURL:
            return "无效的 URL"
        case .requestFailed(let code):
            return "请求失败（错误码：\(code)）"
        case .networkError(let message):
            return "网络错误：\(message)"
        case .decodingError(let message):
            return "数据解析错误：\(message)"
        case .encodingError:
            return "数据编码错误"
        case .notFound:
            return "数据不存在"
        case .unauthorized:
            return "未授权，请检查 API Key"
        }
    }
    
    static func == (lhs: DatabaseServiceError, rhs: DatabaseServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.invalidURL, .invalidURL),
             (.encodingError, .encodingError),
             (.notFound, .notFound),
             (.unauthorized, .unauthorized):
            return true
        case (.requestFailed(let l), .requestFailed(let r)):
            return l == r
        case (.networkError(let l), .networkError(let r)):
            return l == r
        case (.decodingError(let l), .decodingError(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - API Models

/// 日记 API 模型（用于与 Supabase 通信）
struct DiaryAPIModel: Codable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let mediaType: String
    let localMediaPath: String?
    let cloudMediaPath: String?
    let cloudMediaUrl: String?
    let thumbnailPath: String?
    let cloudThumbnailPath: String?
    let cloudThumbnailUrl: String?
    let userInputText: String?
    let aiAnalysisResult: String?
    let diarySummary: String?
    let isAnalyzed: Bool
    let isSummarized: Bool
    let isSaved: Bool
    let syncStatus: String
    let lastErrorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case mediaType = "media_type"
        case localMediaPath = "local_media_path"
        case cloudMediaPath = "cloud_media_path"
        case cloudMediaUrl = "cloud_media_url"
        case thumbnailPath = "thumbnail_path"
        case cloudThumbnailPath = "cloud_thumbnail_path"
        case cloudThumbnailUrl = "cloud_thumbnail_url"
        case userInputText = "user_input_text"
        case aiAnalysisResult = "ai_analysis_result"
        case diarySummary = "diary_summary"
        case isAnalyzed = "is_analyzed"
        case isSummarized = "is_summarized"
        case isSaved = "is_saved"
        case syncStatus = "sync_status"
        case lastErrorMessage = "last_error_message"
    }
    
    /// 从 DiaryEntry 转换
    init(from entry: DiaryEntry) {
        self.id = entry.id
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
        self.mediaType = entry.mediaType.rawValue
        self.localMediaPath = entry.localMediaPath
        self.cloudMediaPath = entry.cloudMediaPath
        self.cloudMediaUrl = entry.cloudMediaURL
        self.thumbnailPath = entry.thumbnailPath
        self.cloudThumbnailPath = entry.cloudThumbnailPath
        self.cloudThumbnailUrl = entry.cloudThumbnailURL
        self.userInputText = entry.userInputText
        self.aiAnalysisResult = entry.aiAnalysisResult
        self.diarySummary = entry.diarySummary
        self.isAnalyzed = entry.isAnalyzed
        self.isSummarized = entry.isSummarized
        self.isSaved = entry.isSaved
        self.syncStatus = entry.syncStatus.rawValue
        self.lastErrorMessage = entry.lastErrorMessage
    }
    
    /// 转换为 DiaryEntry
    func toDiaryEntry(messages: [ChatMessage] = [], tagIds: [UUID] = []) -> DiaryEntry {
        var entry = DiaryEntry(
            id: id,
            createdAt: createdAt,
            mediaType: MediaType(rawValue: mediaType) ?? .photo,
            localMediaPath: localMediaPath,
            thumbnailPath: thumbnailPath
        )
        entry.updatedAt = updatedAt
        entry.cloudMediaPath = cloudMediaPath
        entry.cloudMediaURL = cloudMediaUrl
        entry.cloudThumbnailPath = cloudThumbnailPath
        entry.cloudThumbnailURL = cloudThumbnailUrl
        entry.userInputText = userInputText
        entry.aiAnalysisResult = aiAnalysisResult
        entry.diarySummary = diarySummary
        entry.isAnalyzed = isAnalyzed
        entry.isSummarized = isSummarized
        entry.isSaved = isSaved
        entry.syncStatus = SyncStatus(rawValue: syncStatus) ?? .local
        entry.lastErrorMessage = lastErrorMessage
        entry.messages = messages
        entry.tagIds = tagIds
        return entry
    }
}

/// 消息 API 模型
struct MessageAPIModel: Codable {
    let id: UUID
    let diaryId: UUID
    let sender: String
    let content: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case diaryId = "diary_id"
        case sender
        case content
        case timestamp
    }
    
    init(from message: ChatMessage, diaryId: UUID) {
        self.id = message.id
        self.diaryId = diaryId
        self.sender = message.sender.rawValue
        self.content = message.content
        self.timestamp = message.timestamp
    }
    
    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            sender: ChatSender(rawValue: sender) ?? .user,
            content: content,
            timestamp: timestamp
        )
    }
}

/// 标签 API 模型
struct TagAPIModel: Codable {
    let id: UUID
    let name: String
    let color: String?
    let icon: String?
    let isSystem: Bool
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, icon
        case isSystem = "is_system"
        case sortOrder = "sort_order"
    }
    
    func toTag() -> Tag {
        Tag(
            id: id,
            name: name,
            sortOrder: sortOrder,
            color: color,
            icon: icon,
            isSystem: isSystem
        )
    }
}

// MARK: - Database Service

/// Supabase Database 服务
final class SupabaseDatabaseService {
    
    // MARK: - Singleton
    
    static let shared = SupabaseDatabaseService()
    
    // MARK: - Dependencies
    
    private let config = SupabaseConfig.shared
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
        
        // 配置 JSON 解码器
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        // 配置 JSON 编码器
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Diary CRUD
    
    /// 创建或更新日记（Upsert）
    func upsertDiary(_ entry: DiaryEntry) async throws -> DiaryEntry {
        print("[DatabaseService] Upserting diary: \(entry.id)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        let url = restURL.appendingPathComponent("diaries")
        let apiModel = DiaryAPIModel(from: entry)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try encoder.encode(apiModel)
        } catch {
            throw DatabaseServiceError.encodingError
        }
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseServiceError.requestFailed(statusCode: 0)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw DatabaseServiceError.unauthorized
            }
            throw DatabaseServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        // 解析返回的数据
        do {
            let results = try decoder.decode([DiaryAPIModel].self, from: data)
            if let result = results.first {
                print("[DatabaseService] Diary upserted successfully")
                return result.toDiaryEntry(messages: entry.messages, tagIds: entry.tagIds)
            }
            return entry
        } catch {
            print("[DatabaseService] Decoding error: \(error)")
            throw DatabaseServiceError.decodingError(error.localizedDescription)
        }
    }
    
    /// 获取单个日记
    func getDiary(id: UUID) async throws -> DiaryEntry {
        print("[DatabaseService] Getting diary: \(id)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diaries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([DiaryAPIModel].self, from: data)
        
        guard let diary = results.first else {
            throw DatabaseServiceError.notFound
        }
        
        // 获取关联的消息
        let messages = try await getMessages(for: id)
        
        // 获取关联的标签 IDs
        let tagIds = try await getTagIds(for: id)
        
        return diary.toDiaryEntry(messages: messages, tagIds: tagIds)
    }
    
    /// 获取日记列表
    func getDiaries(tagId: UUID? = nil, limit: Int = 50, offset: Int = 0) async throws -> [DiaryEntry] {
        print("[DatabaseService] Getting diaries, tagId: \(tagId?.uuidString ?? "all")")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diaries"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "is_saved", value: "eq.true")
        ]
        
        // 如果指定了标签，先获取该标签下的日记 IDs
        if let tagId = tagId, tagId.uuidString != "00000000-0000-0000-0000-000000000000" {
            let diaryIds = try await getDiaryIds(for: tagId)
            if diaryIds.isEmpty {
                return []
            }
            let idsString = diaryIds.map { $0.uuidString }.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "id", value: "in.(\(idsString))"))
        }
        
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([DiaryAPIModel].self, from: data)
        
        return results.map { $0.toDiaryEntry() }
    }
    
    /// 删除日记
    func deleteDiary(id: UUID) async throws {
        print("[DatabaseService] Deleting diary: \(id)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diaries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DatabaseServiceError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        print("[DatabaseService] Diary deleted successfully")
    }
    
    // MARK: - Messages
    
    /// 保存消息
    func saveMessages(_ messages: [ChatMessage], for diaryId: UUID) async throws {
        print("[DatabaseService] Saving \(messages.count) messages for diary: \(diaryId)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard !messages.isEmpty else { return }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        // 先删除旧消息
        try await deleteMessages(for: diaryId)
        
        // 插入新消息
        let url = restURL.appendingPathComponent("messages")
        let apiModels = messages.map { MessageAPIModel(from: $0, diaryId: diaryId) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(apiModels)
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DatabaseServiceError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        print("[DatabaseService] Messages saved successfully")
    }
    
    /// 获取消息
    func getMessages(for diaryId: UUID) async throws -> [ChatMessage] {
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "diary_id", value: "eq.\(diaryId.uuidString)"),
            URLQueryItem(name: "order", value: "timestamp.asc")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([MessageAPIModel].self, from: data)
        return results.map { $0.toChatMessage() }
    }
    
    /// 删除消息
    private func deleteMessages(for diaryId: UUID) async throws {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "diary_id", value: "eq.\(diaryId.uuidString)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        _ = try await performRequest(request)
    }
    
    // MARK: - Tags
    
    /// 获取所有标签
    func getTags() async throws -> [Tag] {
        print("[DatabaseService] Getting all tags")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "order", value: "sort_order.asc")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([TagAPIModel].self, from: data)
        return results.map { $0.toTag() }
    }
    
    /// 保存日记标签关联
    func saveDiaryTags(diaryId: UUID, tagIds: [UUID]) async throws {
        print("[DatabaseService] Saving tags for diary: \(diaryId)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard !tagIds.isEmpty else { return }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        // 先删除旧关联
        try await deleteDiaryTags(diaryId: diaryId)
        
        // 插入新关联
        let url = restURL.appendingPathComponent("diary_tags")
        
        struct DiaryTagInsert: Codable {
            let diary_id: UUID
            let tag_id: UUID
        }
        
        let inserts = tagIds.map { DiaryTagInsert(diary_id: diaryId, tag_id: $0) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(inserts)
        
        _ = try await performRequest(request)
        
        print("[DatabaseService] Diary tags saved successfully")
    }
    
    /// 获取日记的标签 IDs
    private func getTagIds(for diaryId: UUID) async throws -> [UUID] {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diary_tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "diary_id", value: "eq.\(diaryId.uuidString)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        struct DiaryTagResult: Codable {
            let tag_id: UUID
        }
        
        let (data, _) = try await performRequest(request)
        let results = try decoder.decode([DiaryTagResult].self, from: data)
        return results.map { $0.tag_id }
    }
    
    /// 获取标签下的日记 IDs
    private func getDiaryIds(for tagId: UUID) async throws -> [UUID] {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diary_tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "tag_id", value: "eq.\(tagId.uuidString)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        struct DiaryTagResult: Codable {
            let diary_id: UUID
        }
        
        let (data, _) = try await performRequest(request)
        let results = try decoder.decode([DiaryTagResult].self, from: data)
        return results.map { $0.diary_id }
    }
    
    /// 删除日记标签关联
    private func deleteDiaryTags(diaryId: UUID) async throws {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diary_tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "diary_id", value: "eq.\(diaryId.uuidString)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        _ = try await performRequest(request)
    }
    
    // MARK: - Private Helpers
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw DatabaseServiceError.networkError(error.localizedDescription)
        }
    }
}
