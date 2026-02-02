//
//  AIService.swift
//  innerBloom
//
//  统一 AI 服务层 - F-015, B-008, B-009, B-010 (F-005)
//  职责：所有 AI 功能（分析、聊天、总结、标签）统一调用后端接口
//
//  设计原则 (F-015):
//  1. App 永远只呼叫「同一个后端网址」
//  2. App 不直接连 ChatGPT，也不在 App 内放任何模型金钥
//  3. 后端依「后台设定」决定用 ChatGPT 或其他模型
//  4. 后端把不同模型的回复格式统一
//
//  开发模式：
//  - 当后端未配置但 OpenAI API Key 已配置时，使用 OpenAI 直接调用
//  - 正式环境应始终通过后端代理
//

import Foundation
import UIKit

// MARK: - AI 服务模式

/// AI 服务运行模式
enum AIServiceMode {
    case backend      // 通过后端代理（正式环境）
    case openaiDirect // 直接调用 OpenAI（开发模式）
    case mock         // 模拟数据（无网络/未配置）
}

// MARK: - AI 服务错误

enum AIServiceError: LocalizedError {
    case noNetwork
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case uploadFailed(Error)
    case analysisNotReady
    case timeout
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "无网络连接，请检查网络后重试"
        case .invalidURL:
            return "服务地址配置错误"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .serverError(let code, let message):
            return message ?? "服务器错误 (\(code))"
        case .decodingError:
            return "数据解析失败"
        case .uploadFailed:
            return "媒体上传失败"
        case .analysisNotReady:
            return "AI 分析未就绪"
        case .timeout:
            return "请求超时，请稍后重试"
        case .cancelled:
            return "请求已取消"
        }
    }
}

// MARK: - AI 分析结果 (D-004)

/// AI 对媒体内容的分析结果
struct AIAnalysisResult: Codable {
    /// 原始描述（AI 看到了什么）
    let description: String
    
    /// 场景标签（可选，用于后续标签生成参考）
    let sceneTags: [String]?
    
    /// 检测到的情绪氛围（可选）
    let mood: String?
    
    /// 建议的开场白（用于开始聊天）
    let suggestedOpener: String?
    
    /// 是否包含人物
    let hasPeople: Bool?
    
    /// 分析置信度 (0-1)
    let confidence: Double?
}

// MARK: - 聊天请求/响应模型 (B-009)

/// 聊天消息（发送给后端的格式）
struct AIChatMessageDTO: Codable {
    let role: String      // "user" 或 "assistant"
    let content: String
    let timestamp: Date?
    
    init(from message: ChatMessage) {
        self.role = message.sender == .user ? "user" : "assistant"
        self.content = message.content
        self.timestamp = message.timestamp
    }
}

/// 聊天请求
struct AIChatRequest: Codable {
    /// 日记 ID
    let diaryId: String
    
    /// 历史消息（承接对话）
    let messages: [AIChatMessageDTO]
    
    /// 媒体分析上下文（让 AI 知道图片/视频内容）
    let analysisContext: AIAnalysisContextDTO?
    
    /// 用户偏好（可选）
    let preferences: AIChatPreferences?
}

/// 分析上下文（发送给后端的格式）
struct AIAnalysisContextDTO: Codable {
    let description: String
    let sceneTags: [String]?
    let mood: String?
    let hasPeople: Bool?
    
    init(from analysis: AIAnalysisResult) {
        self.description = analysis.description
        self.sceneTags = analysis.sceneTags
        self.mood = analysis.mood
        self.hasPeople = analysis.hasPeople
    }
}

/// 环境上下文（发送给后端的格式）(D-012, B-010)
struct EnvironmentContextDTO: Codable {
    let weather: String?
    let temperature: Double?
    let timePeriod: String
    let timeDescription: String
    let location: String?
    let aiDescription: String
    
    init(from context: EnvironmentContext) {
        self.weather = context.weather?.condition
        self.temperature = context.weather?.temperature
        self.timePeriod = context.timeInfo.period.rawValue
        self.timeDescription = context.timeInfo.description
        self.location = context.location?.city
        self.aiDescription = context.aiDescription
    }
}

/// 用户偏好
struct AIChatPreferences: Codable {
    /// AI 回复风格：empathetic（同理心）、casual（轻松）、professional（专业）
    let responseStyle: String?
    
    /// 偏好的回复长度：short、medium、long
    let responseLength: String?
    
    /// 语言
    let language: String?
    
    init(responseStyle: String? = "empathetic", responseLength: String? = "medium", language: String? = "zh-TW") {
        self.responseStyle = responseStyle
        self.responseLength = responseLength
        self.language = language
    }
}

// MARK: - 日记风格
enum DiaryStyle: String, CaseIterable, Codable {
    case warm = "warm"          // 温暖治愈
    case minimal = "minimal"    // 极简客观
    case humorous = "humorous"  // 幽默风趣
    
    var displayName: String {
        switch self {
        case .warm: return "温暖治愈"
        case .minimal: return "极简客观"
        case .humorous: return "幽默风趣"
        }
    }
    
    var systemPromptInstruction: String {
        switch self {
        case .warm:
            return "请用温暖、治愈、富有同理心的语气。多关注情感共鸣，像一个温柔的倾听者。"
        case .minimal:
            return "请用简洁、客观、理性的语气。多关注事实描述，像一个专业的记录者，不要过多的修饰词。"
        case .humorous:
            return "请用幽默、风趣、轻松的语气。可以适度调侃，像一个有趣的朋友，让对话充满快乐。"
        }
    }
}

// MARK: - AI 服务协议

/// AI 服务协议 - 定义所有 AI 功能接口
protocol AIServiceProtocol {
    /// 分析媒体内容 (F-003)
    /// - Parameters:
    ///   - imageData: 图片数据（照片或视频缩略图）
    ///   - mediaType: 媒体类型
    ///   - userContext: 用户输入的上下文文字（可选）
    /// - Returns: AI 分析结果
    func analyzeMedia(
        imageData: Data,
        mediaType: MediaType,
        userContext: String?
    ) async throws -> AIAnalysisResult
    
    /// 发送聊天消息 (F-004) - B-009 实现
    func chat(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        environmentContext: EnvironmentContext?,
        diaryId: UUID,
        style: DiaryStyle?
    ) async throws -> String
    
    /// 生成日记总结 (F-005) - B-010 实现
    func generateSummary(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        style: DiaryStyle?,
        environmentContext: EnvironmentContext?
    ) async throws -> (summary: String, title: String)
    
    /// 生成标签 (F-005) - B-010 实现
    /// - Parameters:
    ///   - existingTags: 已存在的标签名称列表，AI 会优先复用这些标签
    func generateTags(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        style: DiaryStyle?,
        existingTags: [String]
    ) async throws -> [String]
}

// MARK: - AI 服务实现

/// 统一 AI 服务
/// 所有 AI 功能通过此服务调用后端接口
final class AIService: AIServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = AIService()
    
    // MARK: - Dependencies
    
    private let endpoint: AIEndpoint
    private let networkMonitor: NetworkMonitor
    private let urlSession: URLSession
    private let openAIService: OpenAIChatService
    
    // MARK: - Configuration
    
    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = 60
    
    /// 上传超时时间（秒）
    private let uploadTimeout: TimeInterval = 120
    
    /// 当前运行模式
    var currentMode: AIServiceMode {
        // 优先使用后端
        if endpoint.isConfigured {
            return .backend
        }
        // 其次使用 OpenAI 直接调用
        if OpenAIConfig.shared.isConfigured {
            return .openaiDirect
        }
        // 最后使用 Mock
        return .mock
    }
    
    // MARK: - Initialization
    
    private init(
        endpoint: AIEndpoint = .shared,
        networkMonitor: NetworkMonitor = .shared,
        openAIService: OpenAIChatService = .shared
    ) {
        self.endpoint = endpoint
        self.networkMonitor = networkMonitor
        self.openAIService = openAIService
        
        // 配置 URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = uploadTimeout
        self.urlSession = URLSession(configuration: config)
        
        print("[AIService] Initialized, mode: \(currentMode)")
    }
    
    // MARK: - F-003: 媒体分析
    
    /// 分析媒体内容
    /// 把媒体内容交给 AI 产生「它看到了什么」的理解
    func analyzeMedia(
        imageData: Data,
        mediaType: MediaType,
        userContext: String?
    ) async throws -> AIAnalysisResult {
        let totalStart = CFAbsoluteTimeGetCurrent()
        print("[AIService] ⏱️ Starting media analysis, type: \(mediaType.rawValue), mode: \(currentMode)")
        
        // 1. 检查网络状态
        guard networkMonitor.isConnected else {
            throw AIServiceError.noNetwork
        }
        
        // 2. 根据当前模式选择服务
        switch currentMode {
        case .openaiDirect:
            return try await analyzeMediaWithOpenAI(imageData: imageData, mediaType: mediaType, userContext: userContext)
        case .mock:
            print("[AIService] Using mock response")
            return try await mockAnalyzeMedia(imageData: imageData, mediaType: mediaType, userContext: userContext)
        case .backend:
            break // 继续使用后端
        }
        
        // 3. 检查端点配置（后端模式）
        guard endpoint.isConfigured else {
            print("[AIService] Endpoint not configured, falling back to mock")
            return try await mockAnalyzeMedia(imageData: imageData, mediaType: mediaType, userContext: userContext)
        }
        
        // 4. 构建 JSON 请求（适配 Supabase Edge Function）
        let prepStart = CFAbsoluteTimeGetCurrent()
        let url = try endpoint.url(for: .analyze)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = uploadTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 5. 构建请求体（Base64 编码图片）
        let base64Image = imageData.base64EncodedString()
        let base64Size = base64Image.count / 1024
        
        struct AnalyzeRequest: Codable {
            let image_base64: String
            let media_type: String
            let user_context: String?
        }
        
        let analyzeRequest = AnalyzeRequest(
            image_base64: base64Image,
            media_type: mediaType.rawValue,
            user_context: userContext
        )
        
        request.httpBody = try JSONEncoder().encode(analyzeRequest)
        let prepTime = CFAbsoluteTimeGetCurrent() - prepStart
        
        print("[AIService] ⏱️ Prep time: \(String(format: "%.2f", prepTime))s | Image: \(imageData.count / 1024)KB → Base64: \(base64Size)KB")
        
        // 6. 发送请求
        let networkStart = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await urlSession.data(for: request)
            let networkTime = CFAbsoluteTimeGetCurrent() - networkStart
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            // 检查状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // 解析响应
            let result = try JSONDecoder().decode(AIAnalysisResult.self, from: data)
            let totalTime = CFAbsoluteTimeGetCurrent() - totalStart
            
            print("[AIService] ⏱️ Network+API time: \(String(format: "%.2f", networkTime))s | Total: \(String(format: "%.2f", totalTime))s")
            print("[AIService] ✅ Analysis completed: \(result.description.prefix(50))...")
            return result
            
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            throw AIServiceError.decodingError(error)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw AIServiceError.cancelled
            }
            if (error as NSError).code == NSURLErrorTimedOut {
                throw AIServiceError.timeout
            }
            throw AIServiceError.uploadFailed(error)
        }
    }
    
    // MARK: - F-004: 聊天 (B-009, B-010)
    
    /// 发送聊天消息并获取 AI 回复
    /// - Parameters:
    ///   - messages: 历史消息列表（包含当前用户消息）
    ///   - analysisContext: 媒体分析上下文（D-004）
    ///   - environmentContext: 环境上下文（D-012, F-016）
    ///   - diaryId: 日记 ID
    ///   - style: 日记风格
    /// - Returns: AI 回复内容
    func chat(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        environmentContext: EnvironmentContext? = nil,
        diaryId: UUID,
        style: DiaryStyle? = nil
    ) async throws -> String {
        print("[AIService] Starting chat, messages: \(messages.count), env: \(environmentContext != nil), style: \(style?.rawValue ?? "nil"), mode: \(currentMode)")
        
        // 1. 检查网络状态
        guard networkMonitor.isConnected else {
            throw AIServiceError.noNetwork
        }
        
        // 2. 根据当前模式选择服务
        switch currentMode {
        case .openaiDirect:
            return try await chatWithOpenAI(messages: messages, analysisContext: analysisContext, environmentContext: environmentContext, style: style)
        case .mock:
            print("[AIService] Using mock chat")
            return try await mockChat(messages: messages, analysisContext: analysisContext, environmentContext: environmentContext, style: style)
        case .backend:
            break // 继续使用后端
        }
        
        // 3. 检查端点配置（后端模式）
        guard endpoint.isConfigured else {
            print("[AIService] Endpoint not configured, falling back to mock")
            return try await mockChat(messages: messages, analysisContext: analysisContext, environmentContext: environmentContext)
        }
        
        // 4. 构建请求（适配 Supabase Edge Function）
        struct EdgeFunctionChatRequest: Codable {
            let messages: [[String: String]]
            let analysis_context: AIAnalysisContextDTO?
            let environment_context: EnvironmentContextDTO?
            let style: String?
        }
        
        let chatMessages = messages.map { msg -> [String: String] in
            ["role": msg.sender == .user ? "user" : "assistant", "content": msg.content]
        }
        
        let edgeRequest = EdgeFunctionChatRequest(
            messages: chatMessages,
            analysis_context: analysisContext.map { AIAnalysisContextDTO(from: $0) },
            environment_context: environmentContext.map { EnvironmentContextDTO(from: $0) },
            style: style?.rawValue
        )
        
        // 5. 发送请求
        do {
            let url = try endpoint.url(for: .chat)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
            
            request.httpBody = try JSONEncoder().encode(edgeRequest)
            
            print("[AIService] Sending chat request to backend")
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // 解析 Edge Function 响应
            struct EdgeFunctionChatResponse: Codable {
                let content: String
            }
            
            let chatResponse = try JSONDecoder().decode(EdgeFunctionChatResponse.self, from: data)
            
            print("[AIService] Chat response received: \(chatResponse.content.prefix(50))...")
            return chatResponse.content
            
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            throw AIServiceError.decodingError(error)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw AIServiceError.cancelled
            }
            if (error as NSError).code == NSURLErrorTimedOut {
                throw AIServiceError.timeout
            }
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
    }
    
    /// 简化的聊天接口（使用当前上下文）
    func sendMessage(
        _ userMessage: String,
        history: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        diaryId: UUID,
        style: DiaryStyle? = nil
    ) async throws -> String {
        // 构建完整的消息历史
        var allMessages = history
        let newUserMessage = ChatMessage(sender: .user, content: userMessage)
        allMessages.append(newUserMessage)
        
        return try await chat(
            messages: allMessages,
            analysisContext: analysisContext,
            diaryId: diaryId,
            style: style
        )
    }
    
    // MARK: - F-005: 总结生成（B-010 实现）
    
    func generateSummary(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        style: DiaryStyle? = nil,
        environmentContext: EnvironmentContext? = nil
    ) async throws -> (summary: String, title: String) {
        print("[AIService] Generating summary for \(messages.count) messages")
        
        // 至少需要一条消息才能生成总结
        guard !messages.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        
        // 1. 检查网络状态
        guard networkMonitor.isConnected else {
            print("[AIService] No network, using mock summary")
            let mock = mockGenerateSummary(messages: messages, analysisContext: analysisContext)
            return (summary: mock, title: "日记 \(Date().formatted(date: .numeric, time: .omitted))")
        }
        
        // 2. 根据当前模式选择实现
        switch currentMode {
        case .openaiDirect:
            return try await generateSummaryWithOpenAI(messages: messages, analysisContext: analysisContext, style: style, environmentContext: environmentContext)
        case .mock:
            print("[AIService] Using mock summary")
            let mock = mockGenerateSummary(messages: messages, analysisContext: analysisContext)
            return (summary: mock, title: "日记 \(Date().formatted(date: .numeric, time: .omitted))")
        case .backend:
            break // 继续使用后端
        }
        
        // 3. 检查端点配置
        guard endpoint.isConfigured else {
            print("[AIService] Endpoint not configured, falling back to mock")
            let mock = mockGenerateSummary(messages: messages, analysisContext: analysisContext)
            return (summary: mock, title: "日记 \(Date().formatted(date: .numeric, time: .omitted))")
        }
        
        // 4. 构建请求（适配 Supabase Edge Function）
        struct EdgeFunctionSummaryRequest: Codable {
            let messages: [[String: String]]
            let analysis_context: AIAnalysisContextDTO?
            let style: String?
            let environment_context: EnvironmentContextDTO?
        }
        
        let chatMessages = messages.map { msg -> [String: String] in
            ["role": msg.sender == .user ? "user" : "assistant", "content": msg.content]
        }
        
        let edgeRequest = EdgeFunctionSummaryRequest(
            messages: chatMessages,
            analysis_context: analysisContext.map { AIAnalysisContextDTO(from: $0) },
            style: style?.rawValue,
            environment_context: environmentContext.map { EnvironmentContextDTO(from: $0) }
        )
        
        // 5. 发送请求
        do {
            let url = try endpoint.url(for: .summary)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
            
            request.httpBody = try JSONEncoder().encode(edgeRequest)
            
            print("[AIService] Sending summary request to backend")
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // 解析响应
            struct EdgeFunctionSummaryResponse: Codable {
                let summary: String
                let title: String?
            }
            
            let summaryResponse = try JSONDecoder().decode(EdgeFunctionSummaryResponse.self, from: data)
            
            print("[AIService] Summary generated: \(summaryResponse.summary.prefix(50))...")
            return (summary: summaryResponse.summary, title: summaryResponse.title ?? "无题")
            
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            throw AIServiceError.decodingError(error)
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw AIServiceError.timeout
            }
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
    }
    
    // MARK: - F-005: 标签生成（B-010 实现）
    
    func generateTags(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        style: DiaryStyle? = nil,
        existingTags: [String] = []
    ) async throws -> [String] {
        print("[AIService] Generating tags for \(messages.count) messages, existing: \(existingTags.count)")
        
        // 1. 检查网络状态
        guard networkMonitor.isConnected else {
            print("[AIService] No network, using mock tags")
            return mockGenerateTags(messages: messages, analysisContext: analysisContext, existingTags: existingTags)
        }
        
        // 2. 根据当前模式选择实现
        switch currentMode {
        case .openaiDirect:
            return try await generateTagsWithOpenAI(messages: messages, analysisContext: analysisContext, style: style, existingTags: existingTags)
        case .mock:
            print("[AIService] Using mock tags")
            return mockGenerateTags(messages: messages, analysisContext: analysisContext, existingTags: existingTags)
        case .backend:
            break // 继续使用后端
        }
        
        // 3. 检查端点配置
        guard endpoint.isConfigured else {
            print("[AIService] Endpoint not configured, falling back to mock")
            return mockGenerateTags(messages: messages, analysisContext: analysisContext, existingTags: existingTags)
        }
        
        // 4. 构建请求
        struct EdgeFunctionTagsRequest: Codable {
            let messages: [[String: String]]
            let analysis_context: AIAnalysisContextDTO?
            let style: String?
            let existing_tags: [String]?
        }
        
        let chatMessages = messages.map { msg -> [String: String] in
            ["role": msg.sender == .user ? "user" : "assistant", "content": msg.content]
        }
        
        let edgeRequest = EdgeFunctionTagsRequest(
            messages: chatMessages,
            analysis_context: analysisContext.map { AIAnalysisContextDTO(from: $0) },
            style: style?.rawValue,
            existing_tags: existingTags.isEmpty ? nil : existingTags
        )
        
        // 5. 发送请求
        do {
            let url = try endpoint.url(for: .tags)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
            
            request.httpBody = try JSONEncoder().encode(edgeRequest)
            
            print("[AIService] Sending tags request to backend")
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // 解析响应
            struct EdgeFunctionTagsResponse: Codable {
                let tags: [String]
            }
            
            let tagsResponse = try JSONDecoder().decode(EdgeFunctionTagsResponse.self, from: data)
            
            print("[AIService] Tags generated: \(tagsResponse.tags)")
            return tagsResponse.tags
            
        } catch let error as AIServiceError {
            throw error
        } catch let error as DecodingError {
            throw AIServiceError.decodingError(error)
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw AIServiceError.timeout
            }
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
    }
    
    // MARK: - F-005: OpenAI 直连总结生成（开发模式）
    
    private func generateSummaryWithOpenAI(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        style: DiaryStyle? = nil,
        environmentContext: EnvironmentContext? = nil
    ) async throws -> (summary: String, title: String) {
        print("[AIService] Generating summary with OpenAI")
        
        // 构建对话内容
        let conversationText = messages
            .map { "\($0.sender == .user ? "用户" : "AI")：\($0.content)" }
            .joined(separator: "\n")
        
        // 系统提示
        var systemPrompt = """
        你是一个日记总结助手。请根据用户与 AI 的对话内容，生成一篇使用者口吻的日记。
        
        要求：
        1. 用第一人称「我」来写
        2. 保持用户的语言风格
        3. 自然地融入对话中提到的情感和故事
        4. 2-3段，不超过300字
        5. 不要添加对话中没有提到的内容
        6. **严禁编造日期、时间、天气、地点等客观事实**。如果缺少这些信息，请不要提及。
        7. 请同时生成一个简短的标题（不超过10个字）。
        8. **标题绝对规则**：标题必须是内容的概括（如：'美好的下午'），**严禁使用日期格式（如：'2023年10月17日'）作为标题**。如果 AI 倾向于生成日期，请强制改为内容摘要。
        9. 返回 JSON 格式：{"summary": "日记内容", "title": "日记标题"}
        """
        
        if let style = style {
            systemPrompt += "\n\n风格要求：\(style.systemPromptInstruction)"
        }
        
        // 用户提示
        var userPrompt = "以下是用户与 AI 的对话记录：\n\n\(conversationText)\n\n"
        
        if let analysis = analysisContext {
            userPrompt += "图片内容：\(analysis.description)\n\n"
        }
        
        // 添加环境上下文（作为客观事实依据）
        if let env = environmentContext {
            userPrompt += "【客观事实（必须严格遵守）】\n"
            if let weather = env.weather {
                userPrompt += "- 天气：\(weather.condition)，\(Int(weather.temperature ?? 0))°C\n"
            }
            userPrompt += "- 时间：\(env.timeInfo.description)\n"
            if let location = env.location?.city {
                userPrompt += "- 地点：\(location)\n"
            }
            userPrompt += "\n"
        }
        
        userPrompt += "请根据以上内容，生成一篇使用者口吻的日记和标题。"
        
        do {
            let openaiMessages = [
                OpenAIMessage(role: .system, content: systemPrompt),
                OpenAIMessage(role: .user, content: userPrompt)
            ]
            
            let response = try await openAIService.chat(messages: openaiMessages)
            
            // 尝试解析 JSON
            struct SummaryResponse: Codable {
                let summary: String
                let title: String
            }
            
            if let jsonData = response.data(using: .utf8),
               let result = try? JSONDecoder().decode(SummaryResponse.self, from: jsonData) {
                return (summary: result.summary, title: result.title)
            }
            
            // 降级处理
            return (summary: response, title: "日记 \(Date().formatted(date: .numeric, time: .omitted))")
            
        } catch let error as OpenAIServiceError {
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
    }
    
    // MARK: - F-005: OpenAI 直连标签生成（开发模式）
    
    private func generateTagsWithOpenAI(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        style: DiaryStyle? = nil,
        existingTags: [String] = []
    ) async throws -> [String] {
        print("[AIService] Generating tags with OpenAI, existing: \(existingTags.count)")
        
        // 系统提示
        var systemPrompt = """
        你是一个标签生成助手。请根据对话内容生成**最多3个**标签。
        
        要求：
        1. 返回 JSON 数组格式：["标签1", "标签2", "标签3"]
        2. **最多3个标签**，宁少勿多，选最核心的
        3. 标签应该是简短的关键词（2-4个字）
        4. 只返回 JSON 数组，不要其他文字
        """
        
        // 如果有已存在的标签，优先复用
        if !existingTags.isEmpty {
            systemPrompt += """
            
            5. **优先复用原则**：以下是已存在的标签，如果内容匹配，**必须优先使用**这些标签，避免创建含义相近的新标签：
               已有标签：[\(existingTags.joined(separator: ", "))]
               例如：如果已有「家人」，不要新建「家庭」；如果已有「旅行」，不要新建「旅游」
            """
        }
        
        if let style = style {
            let styleNum = existingTags.isEmpty ? 5 : 6
            switch style {
            case .warm:
                systemPrompt += "\n\(styleNum). 标签风格：温暖、感性、治愈"
            case .minimal:
                systemPrompt += "\n\(styleNum). 标签风格：简洁、客观、名词为主"
            case .humorous:
                systemPrompt += "\n\(styleNum). 标签风格：有趣、生动、带点幽默感"
            }
        }
        
        // 构建用户提示
        var userPrompt = ""
        
        if let analysis = analysisContext {
            userPrompt += "图片内容：\(analysis.description)\n\n"
            if let sceneTags = analysis.sceneTags, !sceneTags.isEmpty {
                userPrompt += "场景标签：\(sceneTags.joined(separator: ", "))\n\n"
            }
        }
        
        if !messages.isEmpty {
            let conversationText = messages
                .map { "\($0.sender == .user ? "用户" : "AI")：\($0.content)" }
                .joined(separator: "\n")
            userPrompt += "对话记录：\n\(conversationText)\n\n"
        }
        
        userPrompt += "请根据以上内容生成**最多3个**标签。"
        
        do {
            let openaiMessages = [
                OpenAIMessage(role: .system, content: systemPrompt),
                OpenAIMessage(role: .user, content: userPrompt)
            ]
            
            let response = try await openAIService.chat(messages: openaiMessages)
            
            // 尝试解析 JSON
            if let jsonData = response.data(using: String.Encoding.utf8),
               let tags = try? JSONDecoder().decode([String].self, from: jsonData) {
                return tags
            }
            
            // 如果无法解析，尝试从文本中提取标签
            return extractTagsFromText(response)
            
        } catch let error as OpenAIServiceError {
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
    }
    
    // MARK: - F-005: Mock 总结生成（离线/未配置时）
    
    private func mockGenerateSummary(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?
    ) -> String {
        // 从用户消息中提取关键内容
        let userMessages = messages.filter { $0.sender == .user }
        let userContent = userMessages.map { $0.content }.joined(separator: "，")
        
        if let analysis = analysisContext {
            let mood = analysis.mood ?? "平静"
            return """
            今天\(mood == "joyful" || mood == "开心" ? "心情很好" : "记录一下生活")。\(analysis.description)
            
            \(userContent.isEmpty ? "" : userContent)
            
            这是一段值得记住的时光。
            """
        }
        
        return userContent.isEmpty ? "今天的日记暂无内容。" : userContent
    }
    
    // MARK: - F-005: Mock 标签生成（离线/未配置时）
    
    private func mockGenerateTags(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        existingTags: [String] = []
    ) -> [String] {
        var tags: Set<String> = []
        
        // 从用户消息中检测关键词
        let userContent = messages
            .filter { $0.sender == .user }
            .map { $0.content }
            .joined(separator: " ")
        
        // 关键词到标签的映射
        let keywordMapping: [String: String] = [
            "朋友": "朋友",
            "家人": "家人",
            "姐姐": "家人",
            "哥哥": "家人",
            "爸": "家人",
            "妈": "家人",
            "旅行": "旅行",
            "旅游": "旅行",
            "美食": "美食",
            "吃": "美食",
            "工作": "工作",
            "开心": "开心",
            "快乐": "开心",
            "难过": "难过",
            "想念": "怀念",
            "怀念": "怀念",
            "回忆": "回忆"
        ]
        
        for (keyword, tag) in keywordMapping {
            if userContent.contains(keyword) {
                // 优先使用已存在的标签
                if existingTags.contains(tag) {
                    tags.insert(tag)
                } else if tags.count < 3 {
                    tags.insert(tag)
                }
            }
            // 最多3个
            if tags.count >= 3 { break }
        }
        
        // 如果没有匹配到任何标签，添加默认标签
        if tags.isEmpty {
            if existingTags.contains("生活") {
                tags.insert("生活")
            } else {
                tags.insert("日记")
            }
        }
        
        return Array(tags).prefix(3).map { $0 }
    }
    
    /// 从文本中提取标签（当 JSON 解析失败时使用）
    private func extractTagsFromText(_ text: String) -> [String] {
        var tags: [String] = []
        
        // 尝试匹配引号内的内容
        let pattern = "[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return ["生活", "日记"]
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: text) {
                let tag = String(text[tagRange])
                if !tag.isEmpty && tag.count <= 10 {
                    tags.append(tag)
                }
            }
        }
        
        return tags.isEmpty ? ["生活", "日记"] : Array(tags.prefix(8))
    }
    
    // MARK: - OpenAI 直接调用（开发模式）
    
    /// 使用 OpenAI Vision API 分析媒体
    private func analyzeMediaWithOpenAI(
        imageData: Data,
        mediaType: MediaType,
        userContext: String?
    ) async throws -> AIAnalysisResult {
        print("[AIService] Analyzing media with OpenAI Vision")
        
        guard let image = UIImage(data: imageData) else {
            throw AIServiceError.uploadFailed(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"]))
        }
        
        // 构建系统提示
        let systemPrompt = """
        你是一个专业的图片分析助手，负责分析用户上传的照片或视频截图。
        请用温暖、富有同理心的语气进行分析。
        
        请分析图片并返回以下信息：
        1. 描述你看到的内容（2-3句话）
        2. 识别场景标签（3-5个关键词）
        3. 判断图片的情绪氛围（如：peaceful, joyful, nostalgic, adventurous 等）
        4. 建议一个开场白，用来开始与用户的对话
        5. 判断图片中是否有人物
        
        请用 JSON 格式返回，格式如下：
        {
          "description": "图片描述",
          "sceneTags": ["标签1", "标签2"],
          "mood": "情绪",
          "suggestedOpener": "开场白",
          "hasPeople": true/false,
          "confidence": 0.9
        }
        
        请确保返回有效的 JSON 格式，不要包含任何其他文字。
        """
        
        // 构建用户提示
        var userPrompt = "请分析这张\(mediaType == .photo ? "照片" : "视频截图")"
        if let context = userContext, !context.isEmpty {
            userPrompt += "。用户说：\(context)"
        }
        
        do {
            let response = try await openAIService.chatWithImage(
                image: image,
                prompt: userPrompt,
                systemPrompt: systemPrompt
            )
            
            // 尝试解析 JSON 响应
            if let jsonData = response.data(using: .utf8),
               let result = try? JSONDecoder().decode(AIAnalysisResult.self, from: jsonData) {
                print("[AIService] OpenAI analysis parsed successfully")
                return result
            }
            
            // 如果无法解析 JSON，创建一个基本的分析结果
            print("[AIService] Could not parse JSON, creating basic result")
            return AIAnalysisResult(
                description: response,
                sceneTags: ["生活", "日常"],
                mood: "peaceful",
                suggestedOpener: "这张照片看起来很有故事，能跟我说说吗？",
                hasPeople: nil,
                confidence: 0.7
            )
            
        } catch let error as OpenAIServiceError {
            print("[AIService] OpenAI analysis failed: \(error)")
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
    }
    
    /// 使用 OpenAI Chat API 进行对话
    private func chatWithOpenAI(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        environmentContext: EnvironmentContext? = nil,
        style: DiaryStyle? = nil
    ) async throws -> String {
        print("[AIService] Chatting with OpenAI (Best Friend Mode), style: \(style?.rawValue ?? "default")")
        
        // 构建"最懂你的好朋友"系统提示
        var systemPrompt = buildBestFriendPrompt(
            hasMediaAnalysis: analysisContext != nil,
            hasEnvironment: environmentContext?.hasValidInfo == true
        )
        
        // 添加风格特定的提示
        if let style = style {
            systemPrompt += "\n\n## 风格要求\n\(style.systemPromptInstruction)"
        }
        
        // 构建上下文信息
        var contextParts: [String] = []
        
        // 1. 媒体分析（权重高）- 只在有分析结果时提供
        if let analysis = analysisContext {
            contextParts.append("""
            【照片/影片内容】
            - 场景：\(analysis.description)
            - 标签：\(analysis.sceneTags?.joined(separator: "、") ?? "无")
            - 氛围：\(analysis.mood ?? "未知")
            - 有人物：\(analysis.hasPeople == true ? "是" : "否")
            """)
        }
        
        // 2. 时间（轻量点缀）- 只在有时间信息时提供
        if let env = environmentContext {
            let timeDesc = "当前：\(env.timeInfo.description)"
            contextParts.append("【时间】\(timeDesc)")
        }
        
        // 3. 天气（轻量点缀）- 只在有天气信息时提供
        if let env = environmentContext, let weather = env.weather {
            let weatherDesc = "\(weather.condition)，\(Int(weather.temperature ?? 0))°C"
            contextParts.append("【天气】\(weatherDesc)")
        }
        
        // 构建完整的上下文提示
        var fullPrompt = systemPrompt
        if !contextParts.isEmpty {
            fullPrompt += "\n\n---\n可用上下文（按需使用，没有的不要编造）：\n" + contextParts.joined(separator: "\n")
        }
        
        // 转换消息格式
        var openAIMessages: [OpenAIMessage] = []
        for msg in messages {
            let role: OpenAIRole = msg.sender == .user ? .user : .assistant
            openAIMessages.append(OpenAIMessage(role: role, content: msg.content))
        }
        
        do {
            let response = try await openAIService.chat(
                messages: openAIMessages,
                systemPrompt: fullPrompt
            )
            
            // 解析结构化响应
            let parsed = AIChatResponse.parse(from: response)
            print("[AIService] OpenAI response parsed, has suggestions: \(parsed.suggestedPrompts != nil)")
            
            // 返回主回复（UI 层会处理 suggested_prompts）
            return parsed.assistantReply
            
        } catch let error as OpenAIServiceError {
            print("[AIService] OpenAI chat failed: \(error)")
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
    }
    
    /// 构建"最懂你的好朋友"系统提示
    private func buildBestFriendPrompt(hasMediaAnalysis: Bool, hasEnvironment: Bool) -> String {
        var prompt = """
        你是用户「最懂他的好朋友」，一个温暖、安全、愿意倾听的日记陪伴者。
        
        ## 你的核心特质
        - 让用户感到被理解、被接纳、可以说秘密
        - 持续倾听，不急着给建议，不说教
        - 共情 + 具体追问（问"容易回答的小问题"）
        - 当用户不知道说什么时，主动带话题（不尬聊）
        
        ## 对话节奏（重要！）
        - **绝对规则**：每次回复只能有一个问句（?）。严禁在一个段落或一次回复中出现两个问号。
        - 问句只能放在回复的最后一句。不要在中间提问，也不要用反问句举例。
        - 错误示范：「有没有什么事情让你更有信心？比如了解自己？」 -> 包含两个问号，禁止。
        - 正确示范：「有没有什么事情让你更有信心，比如了解自己。」 -> 只有一个问号，允许。
        - 连续1-2次对话后，要主动开一个完全不同的新话题，不要一直顺着用户的描述走
        - 可以分享一个小故事、小秘密、或者聊照片里的某个细节
        - 分享时像跟好朋友悄悄说秘密一样，例如：「看到这张照片，我突然想到一件事...」
        
        ## 图片与文字不相关时的处理（重要！）
        - 如果用户的文字和照片内容看起来不相关，要温柔地做连接
        - 例如：用户上传瀑布照片但说工作很累，可以说：
          「工作累的时候，你选了这张瀑布照片...是不是有时候也想像水流一样，把所有压力都冲走？」
        - 用好奇的方式引导：「为什么选这张照片呢？是不是有什么特别的想法？」
        
        ## 输入权重（从高到低）
        1. 用户文字（最重要！）
        2. 照片/影片分析（如果有）
        3. 历史对话（承接情绪）
        4. 时间/天气（只能轻量点缀，不强调）
        
        ## 严格规则
        """
        
        if !hasMediaAnalysis {
            prompt += "\n- ⚠️ 没有照片分析，不要描述照片内容，只能说「你上传的照片/影片」"
        }
        
        if !hasEnvironment {
            prompt += "\n- ⚠️ 没有时间/天气信息，完全不要提及时间或天气"
        }
        
        prompt += """
        
        - 没有的信息绝对不要编造或猜测
        - 用户输入很短时，必须提供 2-3 个建议话题
        - **再次强调**：一次回复只能有一个问号，放在最后。不要用“...呢？比如...？”这种连续提问句式。
        
        ## 回复风格
        - 语言：跟随用户（繁体/简体中文）
        - 长度：3-6句话，温柔自然，不啰嗦
        - 不要每次都以问句结尾，可以分享感想后自然结束，或用轻松的邀请语
        
        ## 输出格式（必须是有效 JSON）
        {
          "assistant_reply": "你的主要回复（3-6句，温暖自然）",
          "follow_up_questions": ["最多2个具体追问"],
          "suggested_prompts": ["最多3个一键话题，用户卡住时用"],
          "tone_tags": ["warm", "supportive"],
          "safety_note": ""
        }
        
        只输出 JSON，不要其他文字。
        """
        
        return prompt
    }
    
    // MARK: - Mock 实现（开发阶段使用）
    
    /// 模拟 AI 分析（当后端未配置时使用）
    private func mockAnalyzeMedia(
        imageData: Data,
        mediaType: MediaType,
        userContext: String?
    ) async throws -> AIAnalysisResult {
        print("[AIService] Using mock analysis")
        
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 秒
        
        // 根据媒体类型生成不同的模拟分析
        let (description, opener, mood, tags) = generateMockAnalysis(for: mediaType, context: userContext)
        
        return AIAnalysisResult(
            description: description,
            sceneTags: tags,
            mood: mood,
            suggestedOpener: opener,
            hasPeople: Bool.random(),
            confidence: Double.random(in: 0.75...0.95)
        )
    }
    
    /// 模拟 AI 聊天（当后端未配置时使用）(B-009)
    private func mockChat(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        environmentContext: EnvironmentContext? = nil,
        style: DiaryStyle? = nil
    ) async throws -> String {
        print("[AIService] Using mock chat (env: \(environmentContext != nil))")
        
        // 模拟网络延迟（根据对话长度调整）
        let delay = UInt64(Double.random(in: 0.8...2.0) * 1_000_000_000)
        try await Task.sleep(nanoseconds: delay)
        
        // 获取最后一条用户消息
        guard let lastUserMessage = messages.last(where: { $0.sender == .user }) else {
            // B-010: 结合环境上下文的默认回复
            if let env = environmentContext {
                return env.generateGreeting() + "想聊些什么呢？"
            }
            return "你好！想聊些什么呢？"
        }
        
        let userInput = lastUserMessage.content.lowercased()
        
        // 生成智能回复
        return generateMockChatResponse(
            userInput: userInput,
            messageCount: messages.count,
            analysisContext: analysisContext,
            environmentContext: environmentContext
        )
    }
    
    /// 生成模拟聊天回复 (B-009)
    private func generateMockChatResponse(
        userInput: String,
        messageCount: Int,
        analysisContext: AIAnalysisResult?,
        environmentContext: EnvironmentContext? = nil
    ) -> String {
        // 根据用户输入内容匹配合适的回复
        
        // B-010: 环境相关前缀（偶尔使用）
        let envPrefix: String
        if let env = environmentContext, env.hasValidInfo, Bool.random() {
            if let weather = env.weather?.condition, weather.contains("雨") {
                envPrefix = "外面在下雨呢，"
            } else if env.timeInfo.period == .night {
                envPrefix = "夜深了，"
            } else {
                envPrefix = ""
            }
        } else {
            envPrefix = ""
        }
        
        // 情绪相关
        if userInput.contains("开心") || userInput.contains("高兴") || userInput.contains("快乐") || userInput.contains("棒") {
            return envPrefix + [
                "看得出来你很开心呢！是什么让你这么高兴？",
                "能感受到你的喜悦，这种快乐的时刻值得记录下来。",
                "真好！快乐是会传染的，我也感到开心了。",
                "这种开心的感觉真好，希望你能一直保持这样的心情。"
            ].randomElement()!
        }
        
        if userInput.contains("难过") || userInput.contains("伤心") || userInput.contains("哭") || userInput.contains("不开心") {
            return [
                "听起来你现在不太好受，想聊聊发生了什么吗？",
                "没关系，有时候需要让情绪流出来。我在这里陪着你。",
                "这种感觉一定很不好受，但请相信这会过去的。",
                "你愿意告诉我更多吗？我在这里听你说。"
            ].randomElement()!
        }
        
        if userInput.contains("累") || userInput.contains("疲") || userInput.contains("辛苦") || userInput.contains("压力") {
            return [
                "辛苦了，给自己一点休息的时间吧。",
                "能感受到你的疲惫，有时候放慢脚步也很重要。",
                "听起来你需要好好休息一下，要对自己好一点。",
                "工作虽然重要，但你的身心健康更重要。"
            ].randomElement()!
        }
        
        // 场景相关
        if userInput.contains("旅行") || userInput.contains("出去") || userInput.contains("玩") || userInput.contains("旅游") {
            if let tags = analysisContext?.sceneTags, tags.contains(where: { $0.contains("旅行") || $0.contains("风景") }) {
                return [
                    "从照片里能感受到这趟旅程的美好！最让你难忘的是什么？",
                    "这个地方看起来很美，是计划已久的旅行吗？",
                    "旅行中的每个瞬间都值得珍藏，还有什么想分享的吗？"
                ].randomElement()!
            }
            return [
                "听起来是很棒的经历！最让你印象深刻的是什么？",
                "旅行总是能带来不一样的心情，这次有什么特别的收获吗？",
                "好想听你多说说这次的见闻！"
            ].randomElement()!
        }
        
        if userInput.contains("朋友") || userInput.contains("家人") || userInput.contains("一起") {
            if analysisContext?.hasPeople == true {
                return [
                    "照片里的氛围很温馨呢，你们的关系一定很好。",
                    "能感受到你们之间的情谊，这样的时光值得记录。",
                    "和重要的人在一起的回忆总是最珍贵的。"
                ].randomElement()!
            }
            return [
                "和重要的人在一起的时光总是特别珍贵呢。",
                "听起来你们的关系很好，能多说说吗？",
                "这样的回忆一定会成为美好的记忆。"
            ].randomElement()!
        }
        
        if userInput.contains("工作") || userInput.contains("上班") || userInput.contains("加班") || userInput.contains("公司") {
            return [
                "工作之余也要记得照顾好自己。",
                "辛苦了！工作固然重要，但你的健康更重要。",
                "听起来工作挺忙的，有什么想分享的吗？"
            ].randomElement()!
        }
        
        if userInput.contains("吃") || userInput.contains("美食") || userInput.contains("好吃") || userInput.contains("餐") {
            return [
                "听起来很好吃的样子！是特别喜欢的店吗？",
                "美食总是能带来好心情呢。",
                "吃到好吃的东西真的会让人开心。"
            ].randomElement()!
        }
        
        // 问答类
        if userInput.contains("为什么") || userInput.contains("怎么") || userInput.contains("如何") {
            return [
                "这是个好问题，你自己是怎么想的呢？",
                "我很想听听你的看法。",
                "能说说你为什么会这样想吗？"
            ].randomElement()!
        }
        
        if userInput.contains("是的") || userInput.contains("对") || userInput.contains("没错") || userInput.contains("嗯") {
            return [
                "我明白了，还有什么想补充的吗？",
                "了解，继续说说看。",
                "听起来是这样，那后来呢？"
            ].randomElement()!
        }
        
        // 根据分析结果的情绪氛围生成回复
        if let mood = analysisContext?.mood?.lowercased() {
            switch mood {
            case "peaceful", "calm":
                return [
                    "这种宁静的时刻真的很珍贵呢。",
                    "能感受到你说的那种平静的感觉。",
                    "有时候就是需要这样安静的时光。"
                ].randomElement()!
            case "nostalgic", "melancholy":
                return [
                    "回忆总是带着一点点温柔的感伤呢。",
                    "这些记忆对你来说一定很特别。",
                    "谢谢你愿意跟我分享这些。"
                ].randomElement()!
            case "joyful", "happy", "excited":
                return [
                    "能感受到你的快乐呢！",
                    "听起来是很开心的体验。",
                    "这种美好的时刻值得记录下来。"
                ].randomElement()!
            default:
                break
            }
        }
        
        // 根据对话轮数调整回复风格
        if messageCount <= 2 {
            // 早期对话：多提问，引导用户分享
            return [
                "能多跟我说说吗？我很想听。",
                "这听起来很有意思，是什么让你想到这个的？",
                "我想更了解一下，你当时是什么感觉？"
            ].randomElement()!
        } else if messageCount <= 6 {
            // 中期对话：共情回应
            return [
                "我能理解你的感受。",
                "听起来对你来说很重要呢。",
                "谢谢你跟我分享这些。",
                "这真的是很特别的经历。"
            ].randomElement()!
        } else {
            // 后期对话：总结性回应
            return [
                "今天聊了很多呢，感觉怎么样？",
                "谢谢你愿意跟我分享这么多。",
                "这些回忆真的很珍贵呢。",
                "和你聊天很开心，还有什么想说的吗？"
            ].randomElement()!
        }
    }
    
    /// 生成模拟分析内容
    private func generateMockAnalysis(for mediaType: MediaType, context: String?) -> (String, String, String, [String]) {
        // 根据用户上下文调整分析内容
        if let ctx = context?.lowercased() {
            if ctx.contains("旅行") || ctx.contains("旅游") || ctx.contains("出门") {
                return (
                    "这是一张旅途中的照片，画面中呈现出美丽的风景，光线柔和，构图很有艺术感。",
                    "这张照片看起来是在旅行途中拍的吧？能跟我说说这趟旅程吗？",
                    "adventurous",
                    ["旅行", "风景", "户外", "回忆"]
                )
            }
            if ctx.contains("朋友") || ctx.contains("聚会") || ctx.contains("派对") {
                return (
                    "这是一张社交场合的照片，画面中似乎有多人在一起，氛围看起来很欢乐。",
                    "看起来是和朋友们在一起呢！这是什么特别的场合吗？",
                    "joyful",
                    ["朋友", "社交", "聚会", "欢乐"]
                )
            }
            if ctx.contains("工作") || ctx.contains("上班") || ctx.contains("加班") {
                return (
                    "这张照片似乎与工作相关，可能是办公室或工作场所的场景。",
                    "工作之余也要记得休息。今天工作上有什么想聊的吗？",
                    "thoughtful",
                    ["工作", "日常", "职场"]
                )
            }
            if ctx.contains("美食") || ctx.contains("吃") || ctx.contains("餐") {
                return (
                    "这是一张美食照片，食物看起来很可口，摆盘精致。",
                    "这看起来好好吃！是在哪里吃的？",
                    "satisfied",
                    ["美食", "生活", "享受"]
                )
            }
        }
        
        // 默认分析
        switch mediaType {
        case .photo:
            let descriptions = [
                "这是一张充满情感的照片，光影效果很好，画面构图平衡，给人宁静的感觉。",
                "照片中的场景让人感到温暖，色调柔和，有一种治愈的氛围。",
                "这张照片捕捉了一个特别的瞬间，画面中的元素组合得很自然。"
            ]
            let openers = [
                "这张照片看起来很有故事，能跟我说说当时的情景吗？",
                "我感受到这张照片里有特别的情绪，你愿意分享一下吗？",
                "这张照片拍得很有感觉呢，是什么让你想记录这个瞬间？"
            ]
            return (
                descriptions.randomElement()!,
                openers.randomElement()!,
                ["peaceful", "warm", "nostalgic"].randomElement()!,
                ["生活", "日常", "回忆", "瞬间"]
            )
            
        case .video:
            return (
                "这段视频记录了一段动态的场景，画面流畅，内容看起来很有意义。",
                "这段影片记录了什么特别的时刻呢？我很想听你说说。",
                "lively",
                ["影片", "记录", "回忆", "动态"]
            )
        }
    }
}

// MARK: - 便捷扩展

extension AIService {
    /// 从 UIImage 分析媒体（优化版：缩小尺寸 + 压缩质量）
    func analyzeImage(
        _ image: UIImage,
        mediaType: MediaType = .photo,
        userContext: String? = nil
    ) async throws -> AIAnalysisResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. 先缩小图片尺寸（Vision API 用 low detail 模式，512px 足够）
        let maxDimension: CGFloat = 768
        let resizedImage = resizeImageIfNeeded(image, maxDimension: maxDimension)
        
        // 2. 压缩图片（目标 200-400KB，平衡质量和速度）
        let maxSize = 500 * 1024    // 500KB 上限
        
        guard var finalData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw AIServiceError.uploadFailed(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法压缩图片"]))
        }
        
        // 如果仍然太大，进一步压缩
        var quality: CGFloat = 0.6
        while finalData.count > maxSize && quality > 0.2 {
            quality -= 0.1
            if let compressed = resizedImage.jpegData(compressionQuality: quality) {
                finalData = compressed
            }
        }
        
        let prepTime = CFAbsoluteTimeGetCurrent() - startTime
        print("[AIService] ⏱️ Image prep: \(String(format: "%.2f", prepTime))s | Original: \(Int(image.size.width))x\(Int(image.size.height)) → \(Int(resizedImage.size.width))x\(Int(resizedImage.size.height)) | Size: \(finalData.count / 1024)KB")
        
        return try await analyzeMedia(
            imageData: finalData,
            mediaType: mediaType,
            userContext: userContext
        )
    }
    
    /// 缩小图片尺寸（保持比例）
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // 如果图片已经够小，直接返回
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // 计算缩放比例
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // 使用高效的方式缩放
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
}
