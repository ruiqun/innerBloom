//
//  SupabaseDatabaseService.swift
//  innerBloom
//
//  Supabase Database 服务 - B-005, F-012, B-010 (F-005)
//  负责：日记数据的 CRUD 操作、云端同步、标签管理
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
/// B-019: 新增 user_id 欄位，支援多用戶資料隔離
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
    let userId: String?            // B-019: 多用戶隔離
    
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
        case userId = "user_id"
    }
    
    /// 从 DiaryEntry 转换（B-019: 自动带入当前 user_id）
    init(from entry: DiaryEntry, userId: String? = nil) {
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
        self.userId = userId
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
/// B-019: 新增 user_id 欄位
struct MessageAPIModel: Codable {
    let id: UUID
    let diaryId: UUID
    let sender: String
    let content: String
    let timestamp: Date
    let userId: String?    // B-019: 多用戶隔離
    
    enum CodingKeys: String, CodingKey {
        case id
        case diaryId = "diary_id"
        case sender
        case content
        case timestamp
        case userId = "user_id"
    }
    
    init(from message: ChatMessage, diaryId: UUID, userId: String? = nil) {
        self.id = message.id
        self.diaryId = diaryId
        self.sender = message.sender.rawValue
        self.content = message.content
        self.timestamp = message.timestamp
        self.userId = userId
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
/// B-019: 新增 user_id 欄位
struct TagAPIModel: Codable {
    let id: UUID
    let name: String
    let color: String?
    let icon: String?
    let isSystem: Bool
    let sortOrder: Int
    let userId: String?    // B-019: 多用戶隔離
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, icon
        case isSystem = "is_system"
        case sortOrder = "sort_order"
        case userId = "user_id"
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
    
    // MARK: - B-019 Auth Helpers（多用戶隔離）
    
    /// 取得當前登入使用者的 Access Token（用於 Authorization header）
    /// RLS 需要 user JWT 才能判斷 auth.uid()
    private func getAccessToken() async throws -> String {
        guard let token = await AuthManager.shared.getValidAccessToken() else {
            print("[DatabaseService] ⚠️ No valid access token, user not authenticated")
            throw DatabaseServiceError.unauthorized
        }
        return token
    }
    
    /// 取得當前登入使用者的 user_id
    private var currentUserId: String? {
        AuthManager.shared.currentUserId
    }
    
    /// 建立帶有認證的 URLRequest（B-019: 使用 user JWT 而非 anon key）
    private func authenticatedRequest(url: URL, method: String = "GET") async throws -> URLRequest {
        let token = try await getAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        return request
    }
    
    // MARK: - Diary CRUD
    
    /// 创建或更新日记（Upsert）
    /// B-019: 自動帶入 user_id，使用 user JWT 認證
    func upsertDiary(_ entry: DiaryEntry) async throws -> DiaryEntry {
        print("[DatabaseService] Upserting diary: \(entry.id)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        let url = restURL.appendingPathComponent("diaries")
        let apiModel = DiaryAPIModel(from: entry, userId: currentUserId)
        
        var request = try await authenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try encoder.encode(apiModel)
        } catch {
            throw DatabaseServiceError.encodingError
        }
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseServiceError.requestFailed(statusCode: 0)
        }
        
        print("[DatabaseService] Upsert response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[DatabaseService] Upsert error body: \(errorBody)")
            if httpResponse.statusCode == 401 {
                throw DatabaseServiceError.unauthorized
            }
            throw DatabaseServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        // 解析返回的数据
        // 如果返回空数据但状态码是 2xx，说明操作成功但没有返回 representation
        if data.isEmpty {
            print("[DatabaseService] Diary upserted (no representation returned)")
            return entry
        }
        
        do {
            let results = try decoder.decode([DiaryAPIModel].self, from: data)
            if let result = results.first {
                print("[DatabaseService] Diary upserted successfully")
                return result.toDiaryEntry(messages: entry.messages, tagIds: entry.tagIds)
            }
            print("[DatabaseService] Diary upserted (empty array returned)")
            return entry
        } catch {
            // 如果解码失败，打印原始数据用于调试
            let rawString = String(data: data, encoding: .utf8) ?? "unable to decode"
            print("[DatabaseService] Decoding error: \(error)")
            print("[DatabaseService] Raw response: \(rawString.prefix(500))")
            throw DatabaseServiceError.decodingError(error.localizedDescription)
        }
    }
    
    /// 获取单个日记
    /// B-019: RLS 自動過濾只回傳本人資料
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
        
        let request = try await authenticatedRequest(url: components.url!)
        
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
    
    /// 获取日记列表（B-013：支持按标签筛选，并加载每篇日记的 tagIds）
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
        
        // B-019: 使用 user JWT 認證，RLS 自動過濾
        let request = try await authenticatedRequest(url: components.url!)
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([DiaryAPIModel].self, from: data)
        
        // B-013: 为每篇日记加载关联的 tagIds
        var entries: [DiaryEntry] = []
        for apiModel in results {
            let tagIds = try await getTagIds(for: apiModel.id)
            let entry = apiModel.toDiaryEntry(tagIds: tagIds)
            entries.append(entry)
        }
        
        print("[DatabaseService] Loaded \(entries.count) diaries with tags")
        return entries
    }
    
    /// 搜索日记（B-014, F-008）
    /// - Parameters:
    ///   - keyword: 搜索关键字
    ///   - tagId: 可选的标签 ID，限制搜索范围
    /// - Returns: 匹配的日记列表
    func searchDiaries(keyword: String, tagId: UUID? = nil) async throws -> [DiaryEntry] {
        print("[DatabaseService] Searching diaries for: \(keyword), tagId: \(tagId?.uuidString ?? "all")")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diaries"), resolvingAgainstBaseURL: false)!
        
        // 基础查询条件
        var queryItems = [
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "is_saved", value: "eq.true")
        ]
        
        // 如果指定了标签，先获取该标签下的日记 IDs
        var diaryIdFilter: Set<UUID>? = nil
        if let tagId = tagId, tagId.uuidString != "00000000-0000-0000-0000-000000000000" {
            let diaryIds = try await getDiaryIds(for: tagId)
            if diaryIds.isEmpty {
                return []
            }
            diaryIdFilter = Set(diaryIds)
        }
        
        // 使用 Supabase 的 or 查询搜索多个字段
        // 搜索: title, diary_summary, user_input_text
        let searchPattern = "%\(keyword)%"
        let orCondition = "title.ilike.\(searchPattern),diary_summary.ilike.\(searchPattern),user_input_text.ilike.\(searchPattern)"
        queryItems.append(URLQueryItem(name: "or", value: "(\(orCondition))"))
        
        components.queryItems = queryItems
        
        // B-019: 使用 user JWT 認證，RLS 自動過濾
        let request = try await authenticatedRequest(url: components.url!)
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([DiaryAPIModel].self, from: data)
        
        // 过滤标签范围（如果有指定）
        var filteredResults = results
        if let filter = diaryIdFilter {
            filteredResults = results.filter { filter.contains($0.id) }
        }
        
        // 为每篇日记加载关联的 tagIds
        var entries: [DiaryEntry] = []
        for apiModel in filteredResults {
            let tagIds = try await getTagIds(for: apiModel.id)
            let entry = apiModel.toDiaryEntry(tagIds: tagIds)
            entries.append(entry)
        }
        
        print("[DatabaseService] Search results: \(entries.count) diaries")
        return entries
    }
    
    /// 删除日记
    /// B-019: RLS 確保只能刪除本人資料
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
        
        let request = try await authenticatedRequest(url: components.url!, method: "DELETE")
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DatabaseServiceError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        print("[DatabaseService] Diary deleted successfully")
    }
    
    /// 删除标签
    /// B-019: RLS 確保只能刪除本人標籤
    func deleteTag(id: UUID) async throws {
        print("[DatabaseService] Deleting tag: \(id)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        // 先删除 diary_tags 关联
        var tagComponents = URLComponents(url: restURL.appendingPathComponent("diary_tags"), resolvingAgainstBaseURL: false)!
        tagComponents.queryItems = [URLQueryItem(name: "tag_id", value: "eq.\(id.uuidString)")]
        
        let tagRequest = try await authenticatedRequest(url: tagComponents.url!, method: "DELETE")
        
        let (_, tagResponse) = try await performRequest(tagRequest)
        
        // 检查关联删除结果（仅打印警告，不中断流程）
        if let tagHttpResponse = tagResponse as? HTTPURLResponse,
           !(200...299).contains(tagHttpResponse.statusCode) {
            print("[DatabaseService] Warning: Failed to delete tag associations (status: \(tagHttpResponse.statusCode))")
        }
        
        // 删除标签本身
        var components = URLComponents(url: restURL.appendingPathComponent("tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        
        let request = try await authenticatedRequest(url: components.url!, method: "DELETE")
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DatabaseServiceError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        print("[DatabaseService] Tag deleted successfully")
    }
    
    // MARK: - Messages
    
    /// 保存消息
    /// B-019: 自動帶入 user_id
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
        
        // 插入新消息（B-019: 帶入 user_id）
        let url = restURL.appendingPathComponent("messages")
        let userId = currentUserId
        let apiModels = messages.map { MessageAPIModel(from: $0, diaryId: diaryId, userId: userId) }
        
        var request = try await authenticatedRequest(url: url, method: "POST")
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
    /// B-019: RLS 自動過濾只回傳本人資料
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
        
        let request = try await authenticatedRequest(url: components.url!)
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([MessageAPIModel].self, from: data)
        return results.map { $0.toChatMessage() }
    }
    
    /// 删除消息
    /// B-019: RLS 確保只刪除本人消息
    private func deleteMessages(for diaryId: UUID) async throws {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "diary_id", value: "eq.\(diaryId.uuidString)")]
        
        let request = try await authenticatedRequest(url: components.url!, method: "DELETE")
        
        _ = try await performRequest(request)
    }
    
    // MARK: - Tags
    
    /// 根据名称查找或创建标签 (F-005)
    /// B-019: RLS 自動限定在本人標籤範圍內查找/創建
    func findOrCreateTag(name: String) async throws -> Tag {
        print("[DatabaseService] Finding or creating tag: \(name)")
        
        guard config.isConfigured else {
            throw DatabaseServiceError.notConfigured
        }
        
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        // 1. 先尝试查找已有标签（RLS 自動過濾只搜本人標籤）
        var searchComponents = URLComponents(url: restURL.appendingPathComponent("tags"), resolvingAgainstBaseURL: false)!
        searchComponents.queryItems = [URLQueryItem(name: "name", value: "eq.\(name)")]
        
        let searchRequest = try await authenticatedRequest(url: searchComponents.url!)
        
        let (searchData, _) = try await performRequest(searchRequest)
        let existingTags = try decoder.decode([TagAPIModel].self, from: searchData)
        
        if let existingTag = existingTags.first {
            print("[DatabaseService] Found existing tag: \(existingTag.id)")
            return existingTag.toTag()
        }
        
        // 2. 不存在则创建新标签（B-019: 帶入 user_id）
        print("[DatabaseService] Creating new tag: \(name)")
        
        let createURL = restURL.appendingPathComponent("tags")
        
        struct TagInsert: Codable {
            let id: UUID
            let name: String
            let sort_order: Int
            let is_system: Bool
            let user_id: String?   // B-019: 多用戶隔離
        }
        
        let newTagId = UUID()
        let tagInsert = TagInsert(
            id: newTagId,
            name: name,
            sort_order: 100,
            is_system: false,
            user_id: currentUserId
        )
        
        var createRequest = try await authenticatedRequest(url: createURL, method: "POST")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        createRequest.httpBody = try encoder.encode(tagInsert)
        
        let (createData, response) = try await performRequest(createRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DatabaseServiceError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let createdTags = try decoder.decode([TagAPIModel].self, from: createData)
        
        if let createdTag = createdTags.first {
            print("[DatabaseService] Tag created: \(createdTag.id)")
            return createdTag.toTag()
        }
        
        // 如果创建成功但无法解析，返回本地构建的对象
        return Tag(id: newTagId, name: name, sortOrder: 100, isSystem: false)
    }
    
    /// 获取所有标签
    /// B-019: RLS 自動過濾只回傳本人標籤
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
        
        let request = try await authenticatedRequest(url: components.url!)
        
        let (data, _) = try await performRequest(request)
        
        let results = try decoder.decode([TagAPIModel].self, from: data)
        return results.map { $0.toTag() }
    }
    
    /// 保存日记标签关联
    /// B-019: 自動帶入 user_id
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
        
        // 插入新关联（B-019: 帶入 user_id）
        let url = restURL.appendingPathComponent("diary_tags")
        
        struct DiaryTagInsert: Codable {
            let diary_id: UUID
            let tag_id: UUID
            let user_id: String?   // B-019: 多用戶隔離
        }
        
        let userId = currentUserId
        let inserts = tagIds.map { DiaryTagInsert(diary_id: diaryId, tag_id: $0, user_id: userId) }
        
        var request = try await authenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(inserts)
        
        _ = try await performRequest(request)
        
        print("[DatabaseService] Diary tags saved successfully")
    }
    
    /// 获取日记的标签 IDs
    /// B-019: RLS 自動過濾
    private func getTagIds(for diaryId: UUID) async throws -> [UUID] {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diary_tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "diary_id", value: "eq.\(diaryId.uuidString)")]
        
        let request = try await authenticatedRequest(url: components.url!)
        
        struct DiaryTagResult: Codable {
            let tag_id: UUID
        }
        
        let (data, _) = try await performRequest(request)
        let results = try decoder.decode([DiaryTagResult].self, from: data)
        return results.map { $0.tag_id }
    }
    
    /// 获取标签下的日记 IDs
    /// B-019: RLS 自動過濾
    private func getDiaryIds(for tagId: UUID) async throws -> [UUID] {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diary_tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "tag_id", value: "eq.\(tagId.uuidString)")]
        
        let request = try await authenticatedRequest(url: components.url!)
        
        struct DiaryTagResult: Codable {
            let diary_id: UUID
        }
        
        let (data, _) = try await performRequest(request)
        let results = try decoder.decode([DiaryTagResult].self, from: data)
        return results.map { $0.diary_id }
    }
    
    /// 删除日记标签关联
    /// B-019: RLS 確保只刪除本人關聯
    private func deleteDiaryTags(diaryId: UUID) async throws {
        guard let restURL = config.restURL else {
            throw DatabaseServiceError.invalidURL
        }
        
        var components = URLComponents(url: restURL.appendingPathComponent("diary_tags"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "diary_id", value: "eq.\(diaryId.uuidString)")]
        
        let request = try await authenticatedRequest(url: components.url!, method: "DELETE")
        
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
