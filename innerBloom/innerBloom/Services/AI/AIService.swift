//
//  AIService.swift
//  innerBloom
//
//  统一 AI 服务层 - F-015, B-008, B-009
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

/// 聊天响应
struct AIChatResponse: Codable {
    /// AI 回复内容
    let content: String
    
    /// 检测到的用户情绪（可选）
    let detectedMood: String?
    
    /// 建议的后续问题（可选）
    let suggestedFollowUp: String?
    
    /// 是否应该结束对话的建议
    let shouldWrapUp: Bool?
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
        diaryId: UUID
    ) async throws -> String
    
    /// 生成日记总结 (F-005) - B-010 实现
    func generateSummary(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?
    ) async throws -> String
    
    /// 生成标签 (F-005) - B-010 实现
    func generateTags(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?
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
        print("[AIService] Starting media analysis, type: \(mediaType.rawValue), mode: \(currentMode)")
        
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
        let url = try endpoint.url(for: .analyze)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = uploadTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 5. 构建请求体（Base64 编码图片）
        let base64Image = imageData.base64EncodedString()
        
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
        
        print("[AIService] Sending analyze request to backend, image size: \(imageData.count / 1024)KB")
        
        // 6. 发送请求
        do {
            let (data, response) = try await urlSession.data(for: request)
            
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
            print("[AIService] Analysis completed: \(result.description.prefix(50))...")
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
    
    // MARK: - F-004: 聊天 (B-009)
    
    /// 发送聊天消息并获取 AI 回复
    /// - Parameters:
    ///   - messages: 历史消息列表（包含当前用户消息）
    ///   - analysisContext: 媒体分析上下文（D-004）
    ///   - diaryId: 日记 ID
    /// - Returns: AI 回复内容
    func chat(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?,
        diaryId: UUID
    ) async throws -> String {
        print("[AIService] Starting chat, messages count: \(messages.count), mode: \(currentMode)")
        
        // 1. 检查网络状态
        guard networkMonitor.isConnected else {
            throw AIServiceError.noNetwork
        }
        
        // 2. 根据当前模式选择服务
        switch currentMode {
        case .openaiDirect:
            return try await chatWithOpenAI(messages: messages, analysisContext: analysisContext)
        case .mock:
            print("[AIService] Using mock chat")
            return try await mockChat(messages: messages, analysisContext: analysisContext)
        case .backend:
            break // 继续使用后端
        }
        
        // 3. 检查端点配置（后端模式）
        guard endpoint.isConfigured else {
            print("[AIService] Endpoint not configured, falling back to mock")
            return try await mockChat(messages: messages, analysisContext: analysisContext)
        }
        
        // 4. 构建请求（适配 Supabase Edge Function）
        struct EdgeFunctionChatRequest: Codable {
            let messages: [[String: String]]
            let analysis_context: AIAnalysisContextDTO?
        }
        
        let chatMessages = messages.map { msg -> [String: String] in
            ["role": msg.sender == .user ? "user" : "assistant", "content": msg.content]
        }
        
        let edgeRequest = EdgeFunctionChatRequest(
            messages: chatMessages,
            analysis_context: analysisContext.map { AIAnalysisContextDTO(from: $0) }
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
        diaryId: UUID
    ) async throws -> String {
        // 构建完整的消息历史
        var allMessages = history
        let newUserMessage = ChatMessage(sender: .user, content: userMessage)
        allMessages.append(newUserMessage)
        
        return try await chat(
            messages: allMessages,
            analysisContext: analysisContext,
            diaryId: diaryId
        )
    }
    
    // MARK: - F-005: 总结生成（B-010 实现）
    
    func generateSummary(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?
    ) async throws -> String {
        // TODO: B-010 实现
        print("[AIService] Summary generation - will be implemented in B-010")
        throw AIServiceError.analysisNotReady
    }
    
    // MARK: - F-005: 标签生成（B-010 实现）
    
    func generateTags(
        messages: [ChatMessage],
        analysisContext: AIAnalysisResult?
    ) async throws -> [String] {
        // TODO: B-010 实现
        print("[AIService] Tag generation - will be implemented in B-010")
        throw AIServiceError.analysisNotReady
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
        analysisContext: AIAnalysisResult?
    ) async throws -> String {
        print("[AIService] Chatting with OpenAI")
        
        // 构建系统提示
        var systemPrompt = """
        你是一个温暖、善解人意的日记陪伴助手。用户正在通过照片或视频记录生活，你的任务是：
        1. 用温暖、富有同理心的语气与用户对话
        2. 引导用户分享照片背后的故事和感受
        3. 适时给予情感支持和鼓励
        4. 保持对话自然流畅，像朋友一样交流
        
        回复要求：
        - 使用繁体中文或简体中文（跟随用户的语言）
        - 回复简洁，通常2-4句话
        - 多用问句引导用户继续分享
        - 避免说教或给太多建议
        """
        
        // 添加媒体分析上下文
        if let analysis = analysisContext {
            systemPrompt += """
            
            关于用户上传的媒体内容：
            - 场景描述：\(analysis.description)
            - 场景标签：\(analysis.sceneTags?.joined(separator: ", ") ?? "未知")
            - 情绪氛围：\(analysis.mood ?? "未知")
            - 是否有人物：\(analysis.hasPeople == true ? "是" : "否")
            
            请结合这些信息来回应用户。
            """
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
                systemPrompt: systemPrompt
            )
            
            print("[AIService] OpenAI chat response received")
            return response
            
        } catch let error as OpenAIServiceError {
            print("[AIService] OpenAI chat failed: \(error)")
            throw AIServiceError.serverError(statusCode: -1, message: error.localizedDescription)
        }
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
        analysisContext: AIAnalysisResult?
    ) async throws -> String {
        print("[AIService] Using mock chat")
        
        // 模拟网络延迟（根据对话长度调整）
        let delay = UInt64(Double.random(in: 0.8...2.0) * 1_000_000_000)
        try await Task.sleep(nanoseconds: delay)
        
        // 获取最后一条用户消息
        guard let lastUserMessage = messages.last(where: { $0.sender == .user }) else {
            return "你好！想聊些什么呢？"
        }
        
        let userInput = lastUserMessage.content.lowercased()
        
        // 生成智能回复
        return generateMockChatResponse(
            userInput: userInput,
            messageCount: messages.count,
            analysisContext: analysisContext
        )
    }
    
    /// 生成模拟聊天回复 (B-009)
    private func generateMockChatResponse(
        userInput: String,
        messageCount: Int,
        analysisContext: AIAnalysisResult?
    ) -> String {
        // 根据用户输入内容匹配合适的回复
        
        // 情绪相关
        if userInput.contains("开心") || userInput.contains("高兴") || userInput.contains("快乐") || userInput.contains("棒") {
            return [
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
    /// 从 UIImage 分析媒体
    func analyzeImage(
        _ image: UIImage,
        mediaType: MediaType = .photo,
        userContext: String? = nil
    ) async throws -> AIAnalysisResult {
        // 压缩图片用于分析（最大 1MB）
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AIServiceError.uploadFailed(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法压缩图片"]))
        }
        
        // 如果仍然太大，进一步压缩
        let maxSize = 1024 * 1024 // 1MB
        var finalData = imageData
        var quality: CGFloat = 0.7
        
        while finalData.count > maxSize && quality > 0.1 {
            quality -= 0.1
            if let compressed = image.jpegData(compressionQuality: quality) {
                finalData = compressed
            }
        }
        
        print("[AIService] Image compressed: \(finalData.count / 1024)KB")
        
        return try await analyzeMedia(
            imageData: finalData,
            mediaType: mediaType,
            userContext: userContext
        )
    }
}
