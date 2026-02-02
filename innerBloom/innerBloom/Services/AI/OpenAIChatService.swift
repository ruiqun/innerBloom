//
//  OpenAIChatService.swift
//  innerBloom
//
//  OpenAI Chat API 直接调用服务 - 开发模式
//  ⚠️ 注意：正式环境应通过后端代理调用（F-015）
//
//  支持功能：
//  - Chat Completions API (gpt-4o-mini, gpt-4.1)
//  - Vision API（图片分析）
//  - 多轮对话上下文
//

import Foundation
import UIKit

// MARK: - OpenAI API 请求/响应模型

/// OpenAI 消息角色
enum OpenAIRole: String, Codable {
    case system
    case user
    case assistant
    case developer  // 新版 API 使用 developer 替代 system
}

/// OpenAI 消息内容（支持文本和图片）
enum OpenAIMessageContent: Codable {
    case text(String)
    case multipart([OpenAIContentPart])
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .multipart(let parts):
            try container.encode(parts)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let parts = try? container.decode([OpenAIContentPart].self) {
            self = .multipart(parts)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid content")
        }
    }
}

/// OpenAI 内容部分（用于多模态消息）
struct OpenAIContentPart: Codable {
    let type: String
    let text: String?
    let image_url: OpenAIImageURL?
    
    static func text(_ content: String) -> OpenAIContentPart {
        OpenAIContentPart(type: "text", text: content, image_url: nil)
    }
    
    static func imageURL(_ url: String, detail: String = "auto") -> OpenAIContentPart {
        OpenAIContentPart(type: "image_url", text: nil, image_url: OpenAIImageURL(url: url, detail: detail))
    }
    
    static func imageBase64(_ base64: String, mimeType: String = "image/jpeg", detail: String = "auto") -> OpenAIContentPart {
        let dataURL = "data:\(mimeType);base64,\(base64)"
        return OpenAIContentPart(type: "image_url", text: nil, image_url: OpenAIImageURL(url: dataURL, detail: detail))
    }
}

/// OpenAI 图片 URL
struct OpenAIImageURL: Codable {
    let url: String
    let detail: String?
    
    init(url: String, detail: String? = "auto") {
        self.url = url
        self.detail = detail
    }
}

/// OpenAI 消息
struct OpenAIMessage: Codable {
    let role: OpenAIRole
    let content: OpenAIMessageContent
    
    init(role: OpenAIRole, content: String) {
        self.role = role
        self.content = .text(content)
    }
    
    init(role: OpenAIRole, parts: [OpenAIContentPart]) {
        self.role = role
        self.content = .multipart(parts)
    }
}

/// OpenAI Chat Completions 请求
struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double?
    let max_tokens: Int?
    let top_p: Double?
    let frequency_penalty: Double?
    let presence_penalty: Double?
    
    init(
        model: String = "gpt-4o-mini",
        messages: [OpenAIMessage],
        temperature: Double? = 0.7,
        max_tokens: Int? = 1000,
        top_p: Double? = nil,
        frequency_penalty: Double? = nil,
        presence_penalty: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.top_p = top_p
        self.frequency_penalty = frequency_penalty
        self.presence_penalty = presence_penalty
    }
}

/// OpenAI Chat Completions 响应
struct OpenAIChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

/// OpenAI 选择
struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIResponseMessage
    let finish_reason: String?
}

/// OpenAI 响应消息
struct OpenAIResponseMessage: Codable {
    let role: String
    let content: String?
}

/// OpenAI 使用量
struct OpenAIUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

/// OpenAI 错误响应
struct OpenAIErrorResponse: Codable {
    let error: OpenAIError
}

struct OpenAIError: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - OpenAI Chat Service

/// OpenAI Chat 服务
/// 直接调用 OpenAI API（开发模式）
final class OpenAIChatService {
    
    // MARK: - Singleton
    
    static let shared = OpenAIChatService()
    
    // MARK: - Configuration
    
    /// OpenAI API 基础 URL
    private let baseURL = "https://api.openai.com/v1"
    
    /// 默认模型
    var defaultModel: String = "gpt-4o-mini"
    
    /// Vision 模型（支持图片）
    var visionModel: String = "gpt-4o-mini"
    
    /// 请求超时时间
    private let timeout: TimeInterval = 60
    
    /// API Key
    private var apiKey: String {
        OpenAIConfig.shared.apiKey
    }
    
    // MARK: - URLSession
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        return URLSession(configuration: config)
    }()
    
    // MARK: - Initialization
    
    private init() {
        print("[OpenAIChatService] Initialized")
    }
    
    // MARK: - Chat Completions
    
    /// 发送聊天消息
    /// - Parameters:
    ///   - messages: 消息历史
    ///   - systemPrompt: 系统提示词
    ///   - model: 模型名称
    /// - Returns: AI 回复内容
    func chat(
        messages: [OpenAIMessage],
        systemPrompt: String? = nil,
        model: String? = nil
    ) async throws -> String {
        // 检查 API Key
        guard !apiKey.isEmpty else {
            throw OpenAIServiceError.noAPIKey
        }
        
        // 构建完整消息列表
        var allMessages: [OpenAIMessage] = []
        
        // 添加系统提示
        if let prompt = systemPrompt {
            allMessages.append(OpenAIMessage(role: .developer, content: prompt))
        }
        
        // 添加历史消息
        allMessages.append(contentsOf: messages)
        
        // 构建请求
        let request = OpenAIChatRequest(
            model: model ?? defaultModel,
            messages: allMessages
        )
        
        // 发送请求
        return try await sendChatRequest(request)
    }
    
    /// 发送带图片的聊天消息（Vision）
    /// - Parameters:
    ///   - image: 图片
    ///   - prompt: 用户提示
    ///   - systemPrompt: 系统提示
    /// - Returns: AI 回复
    func chatWithImage(
        image: UIImage,
        prompt: String,
        systemPrompt: String? = nil
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIServiceError.noAPIKey
        }
        
        // 压缩图片并转为 Base64
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw OpenAIServiceError.imageEncodingFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        print("[OpenAIChatService] Image encoded: \(imageData.count / 1024)KB")
        
        // 构建消息
        var messages: [OpenAIMessage] = []
        
        if let sysPrompt = systemPrompt {
            messages.append(OpenAIMessage(role: .developer, content: sysPrompt))
        }
        
        // 添加带图片的用户消息
        let userMessage = OpenAIMessage(
            role: .user,
            parts: [
                .text(prompt),
                .imageBase64(base64Image)
            ]
        )
        messages.append(userMessage)
        
        // 构建请求（使用 Vision 模型）
        let request = OpenAIChatRequest(
            model: visionModel,
            messages: messages,
            max_tokens: 1000
        )
        
        return try await sendChatRequest(request)
    }
    
    // MARK: - Private Methods
    
    /// 发送 Chat Completions 请求
    private func sendChatRequest(_ chatRequest: OpenAIChatRequest) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(chatRequest)
        
        print("[OpenAIChatService] Sending request to OpenAI...")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIServiceError.invalidResponse
            }
            
            // 检查状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                // 尝试解析错误信息
                if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    throw OpenAIServiceError.apiError(
                        code: httpResponse.statusCode,
                        message: errorResponse.error.message
                    )
                }
                throw OpenAIServiceError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // 解析响应
            let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            
            guard let content = chatResponse.choices.first?.message.content else {
                throw OpenAIServiceError.emptyResponse
            }
            
            print("[OpenAIChatService] Response received, tokens: \(chatResponse.usage?.total_tokens ?? 0)")
            
            return content
            
        } catch let error as OpenAIServiceError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw OpenAIServiceError.timeout
            }
            throw OpenAIServiceError.networkError(error)
        }
    }
}

// MARK: - OpenAI Service Error

enum OpenAIServiceError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case emptyResponse
    case httpError(statusCode: Int)
    case apiError(code: Int, message: String)
    case imageEncodingFailed
    case timeout
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "未配置 OpenAI API Key"
        case .invalidResponse:
            return "无效的响应"
        case .emptyResponse:
            return "AI 返回了空响应"
        case .httpError(let code):
            return "HTTP 错误 (\(code))"
        case .apiError(_, let message):
            return message
        case .imageEncodingFailed:
            return "图片编码失败"
        case .timeout:
            return "请求超时"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}

// MARK: - OpenAI Config

/// OpenAI 配置
final class OpenAIConfig {
    
    static let shared = OpenAIConfig()
    
    /// API Key
    /// 配置方式（优先级从高到低）：
    /// 1. 环境变量 OPENAI_API_KEY
    /// 2. Supabase.plist 中的 OPENAI_API_KEY
    var apiKey: String {
        // 优先从环境变量读取
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return envKey
        }
        return _apiKey
    }
    
    private var _apiKey: String = ""
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        // 从 Supabase.plist 加载
        if let plistPath = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
           let plistData = FileManager.default.contents(atPath: plistPath),
           let config = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: String] {
            
            if let key = config["OPENAI_API_KEY"], !key.isEmpty {
                _apiKey = key
                print("[OpenAIConfig] API Key loaded from Supabase.plist")
            }
        }
    }
    
    /// 手动设置 API Key
    func configure(apiKey: String) {
        _apiKey = apiKey
        print("[OpenAIConfig] API Key configured manually")
    }
    
    /// 检查是否已配置
    var isConfigured: Bool {
        !apiKey.isEmpty
    }
}
