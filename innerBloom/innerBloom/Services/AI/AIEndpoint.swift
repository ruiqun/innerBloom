//
//  AIEndpoint.swift
//  innerBloom
//
//  AI 服务端点配置 - F-015, B-008
//  职责：管理后端 AI 服务的 URL 配置
//
//  设计说明 (F-015):
//  - App 永远只呼叫「同一个后端网址」
//  - 后端负责：模型选择（ChatGPT 或其他）、金钥管理、响应格式统一
//  - App 只需要知道后端地址，不需要知道使用哪个模型
//
//  推荐配置（正式环境）:
//  - 使用 Supabase Edge Functions 作为后端代理
//  - API Key 存储在 Supabase 环境变量中
//  - 基础 URL: https://your-project.supabase.co/functions/v1/ai-chat
//

import Foundation

// MARK: - API 路由

/// AI 服务 API 路由
enum AIAPIRoute: String {
    /// 媒体分析 (F-003)
    case analyze = "/analyze"
    
    /// 聊天对话 (F-004)
    case chat = "/chat"
    
    /// 生成总结 (F-005)
    case summary = "/summary"
    
    /// 生成标签 (F-005)
    case tags = "/tags"
    
    /// 健康检查
    case health = "/health"
}

// MARK: - AI 端点配置

/// AI 服务端点配置
/// 管理后端 AI 服务的连接信息
final class AIEndpoint {
    
    // MARK: - Singleton
    
    static let shared = AIEndpoint()
    
    // MARK: - Configuration
    
    /// 后端服务基础 URL
    /// 配置优先级：
    /// 1. 环境变量 AI_BACKEND_URL
    /// 2. Supabase.plist 中的 AI_BACKEND_URL
    /// 3. 自动生成 Supabase Edge Function URL
    var baseURL: String {
        // 优先从环境变量读取
        if let envURL = ProcessInfo.processInfo.environment["AI_BACKEND_URL"], !envURL.isEmpty {
            return envURL
        }
        // 使用配置文件中的值
        if !_baseURL.isEmpty && !_baseURL.contains("localhost") {
            return _baseURL
        }
        // 自动生成 Supabase Edge Function URL
        return supabaseEdgeFunctionURL
    }
    
    /// Supabase Edge Function URL（自动生成）
    private var supabaseEdgeFunctionURL: String {
        let supabaseURL = SupabaseConfig.shared.projectURL
        // 从 https://xxx.supabase.co 转换为 https://xxx.supabase.co/functions/v1/ai-chat
        return "\(supabaseURL)/functions/v1/ai-chat"
    }
    
    /// API 密钥（用于后端鉴权，Supabase 使用 anon key）
    var apiKey: String {
        if let envKey = ProcessInfo.processInfo.environment["AI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if !_apiKey.isEmpty {
            return _apiKey
        }
        // 使用 Supabase anon key
        return SupabaseConfig.shared.anonKey
    }
    
    // MARK: - Private Storage
    
    /// 基础 URL（内部存储）
    private var _baseURL: String = ""
    
    /// API 密钥（内部存储）
    private var _apiKey: String = ""
    
    // MARK: - Initialization
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Methods
    
    /// 从配置文件加载
    private func loadConfiguration() {
        // 尝试从 Supabase.plist 加载
        if let plistPath = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
           let plistData = FileManager.default.contents(atPath: plistPath),
           let config = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: String] {
            
            if let url = config["AI_BACKEND_URL"], !url.isEmpty {
                _baseURL = url
            }
            if let key = config["AI_API_KEY"], !key.isEmpty {
                _apiKey = key
            }
        }
        
        print("[AIEndpoint] Base URL: \(baseURL)")
        print("[AIEndpoint] Using Supabase Edge Function: \(baseURL.contains("functions/v1"))")
    }
    
    /// 手动配置（用于测试或动态切换）
    func configure(baseURL: String, apiKey: String? = nil) {
        _baseURL = baseURL
        if let key = apiKey {
            _apiKey = key
        }
        print("[AIEndpoint] Configuration updated: \(baseURL)")
    }
    
    /// 检查配置是否有效
    /// 当 Supabase 已配置时，自动认为 AI 端点可用
    var isConfigured: Bool {
        // 如果有自定义的后端 URL，使用它
        if !_baseURL.isEmpty && !_baseURL.contains("localhost") {
            return true
        }
        // 否则检查 Supabase 是否已配置
        return SupabaseConfig.shared.isConfigured
    }
    
    // MARK: - URL Builders
    
    /// 构建完整的 API URL
    /// - Parameter route: API 路由
    /// - Returns: 完整 URL
    func url(for route: AIAPIRoute) throws -> URL {
        let fullPath = baseURL + route.rawValue
        guard let url = URL(string: fullPath) else {
            throw AIServiceError.invalidURL
        }
        return url
    }
    
    /// 构建带查询参数的 URL
    func url(for route: AIAPIRoute, queryItems: [URLQueryItem]) throws -> URL {
        let baseURL = try url(for: route)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        
        guard let finalURL = components?.url else {
            throw AIServiceError.invalidURL
        }
        return finalURL
    }
}

// MARK: - Debug Helpers

extension AIEndpoint {
    /// 打印配置信息（调试用）
    func printDebugInfo() {
        print("[AIEndpoint] Debug Info:")
        print("  - Base URL: \(baseURL)")
        print("  - Is Configured: \(isConfigured)")
        print("  - API Key Set: \(!_apiKey.isEmpty)")
    }
    
    /// 测试连接
    func testConnection() async -> Bool {
        do {
            let healthURL = try url(for: .health)
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            print("[AIEndpoint] Connection test failed: \(error)")
            return false
        }
    }
}

// MARK: - HTTP 请求构建器

extension AIEndpoint {
    /// 创建基础请求
    func createRequest(for route: AIAPIRoute, method: String = "GET") throws -> URLRequest {
        let url = try url(for: route)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加 API Key（如果有）
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    /// 创建 JSON POST 请求
    func createJSONRequest<T: Encodable>(
        for route: AIAPIRoute,
        body: T
    ) throws -> URLRequest {
        var request = try createRequest(for: route, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
