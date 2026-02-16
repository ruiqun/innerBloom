//
//  AuthManager.swift
//  innerBloom
//
//  认证管理器 - B-018
//  负责：Supabase Auth 对接（Email OTP / Email+密码）
//  支持：登入、注册、登出、Session 管理、Token 自动刷新
//

import Foundation

// MARK: - Auth Error

/// 认证错误
enum AuthError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidEmail
    case invalidOTP
    case invalidPassword
    case networkError(String)
    case serverError(Int, String)
    case sessionExpired
    case noSession
    case decodingError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "雲端服務未配置"
        case .invalidURL:
            return "無效的服務地址"
        case .invalidEmail:
            return "請輸入有效的 Email"
        case .invalidOTP:
            return "驗證碼不正確或已過期"
        case .invalidPassword:
            return "密碼長度至少 6 位"
        case .networkError(let msg):
            return "網路錯誤：\(msg)"
        case .serverError(_, let msg):
            return msg
        case .sessionExpired:
            return "登入已過期，請重新登入"
        case .noSession:
            return "尚未登入"
        case .decodingError(let msg):
            return "資料解析錯誤：\(msg)"
        case .unknown(let msg):
            return msg
        }
    }
}

// MARK: - Auth State

/// 认证状态
enum AuthState: Equatable {
    case unknown        // App 刚启动，尚未确认
    case unauthenticated // 未登入
    case authenticated   // 已登入
}

// MARK: - Auth Session

/// 认证 Session 模型
struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int          // 秒
    let expiresAt: Date         // 过期时间
    let userId: String
    let userEmail: String?
    
    /// 是否已过期
    var isExpired: Bool {
        Date() >= expiresAt
    }
    
    /// 是否即将过期（提前 60 秒刷新）
    var isNearExpiry: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }
}

// MARK: - Supabase Auth Response Models

/// Supabase Auth Token 响应
private struct SupabaseAuthTokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let expires_at: Int?
    let token_type: String?
    let user: SupabaseAuthUser?
}

/// Supabase Auth 用户
private struct SupabaseAuthUser: Codable {
    let id: String
    let email: String?
    let created_at: String?
}

/// Supabase Auth 错误响应
private struct SupabaseAuthError: Codable {
    let error: String?
    let error_description: String?
    let msg: String?
    let message: String?
    
    var displayMessage: String {
        error_description ?? message ?? msg ?? error ?? "未知錯誤"
    }
}

// MARK: - Auth Manager

/// 认证管理器
/// 使用 @Observable 宏（遵循项目规范）
@Observable
final class AuthManager {
    
    // MARK: - Singleton
    
    static let shared = AuthManager()
    
    // MARK: - Properties
    
    /// 当前认证状态
    private(set) var authState: AuthState = .unknown
    
    /// 当前 Session
    private(set) var currentSession: AuthSession?
    
    /// 当前用户 Email
    var currentUserEmail: String? {
        currentSession?.userEmail
    }
    
    /// 当前用户 ID
    var currentUserId: String? {
        currentSession?.userId
    }
    
    /// 是否已登入
    var isAuthenticated: Bool {
        authState == .authenticated && currentSession != nil
    }
    
    /// 是否正在加载（登入/注册/验证中）
    private(set) var isLoading: Bool = false
    
    /// 错误消息
    private(set) var errorMessage: String?
    
    // MARK: - Private
    
    private let config = SupabaseConfig.shared
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    /// Session 存储 Key
    private let sessionStorageKey = "com.innerbloom.authSession"
    
    // MARK: - Initialization
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // 尝试从本机恢复 Session
        restoreSession()
    }
    
    // MARK: - Session Management
    
    /// 恢复已保存的 Session（App 启动时调用）
    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey) else {
            print("[AuthManager] No saved session found")
            authState = .unauthenticated
            return
        }
        
        do {
            let savedSession = try JSONDecoder().decode(AuthSession.self, from: data)
            
            if savedSession.isExpired {
                // Token 已过期，尝试刷新
                print("[AuthManager] Saved session expired, attempting refresh...")
                Task {
                    await refreshTokenIfNeeded(refreshToken: savedSession.refreshToken)
                }
            } else {
                // Session 有效
                currentSession = savedSession
                authState = .authenticated
                print("[AuthManager] Session restored for: \(savedSession.userEmail ?? "unknown")")
            }
        } catch {
            print("[AuthManager] Failed to decode saved session: \(error)")
            clearSession()
        }
    }
    
    /// 保存 Session 到本机
    private func saveSession(_ session: AuthSession) {
        currentSession = session
        authState = .authenticated
        
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
            print("[AuthManager] Session saved for: \(session.userEmail ?? "unknown")")
        } catch {
            print("[AuthManager] Failed to save session: \(error)")
        }
    }
    
    /// 清除 Session
    private func clearSession() {
        currentSession = nil
        authState = .unauthenticated
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        print("[AuthManager] Session cleared")
    }
    
    /// 获取有效的 Access Token（自动刷新）
    func getValidAccessToken() async -> String? {
        guard let session = currentSession else { return nil }
        
        if session.isNearExpiry {
            await refreshTokenIfNeeded(refreshToken: session.refreshToken)
        }
        
        return currentSession?.accessToken
    }
    
    // MARK: - Email OTP Flow
    
    /// 发送 OTP 验证码到 Email
    /// - Parameter email: 用户 Email
    func sendOTP(to email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard isValidEmail(trimmedEmail) else {
            throw AuthError.invalidEmail
        }
        
        guard config.isConfigured else {
            throw AuthError.notConfigured
        }
        
        guard let authURL = config.authURL else {
            throw AuthError.invalidURL
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let url = authURL.appendingPathComponent("otp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": trimmedEmail
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("無法連接到伺服器")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = parseErrorMessage(from: data)
            print("[AuthManager] Send OTP failed: \(httpResponse.statusCode) - \(errorMsg)")
            throw AuthError.serverError(httpResponse.statusCode, errorMsg)
        }
        
        print("[AuthManager] OTP sent to: \(trimmedEmail)")
    }
    
    /// 验证 OTP 并登入
    /// - Parameters:
    ///   - email: 用户 Email
    ///   - otp: 验证码
    func verifyOTP(email: String, otp: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedOTP = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedOTP.isEmpty else {
            throw AuthError.invalidOTP
        }
        
        guard config.isConfigured else {
            throw AuthError.notConfigured
        }
        
        guard let authURL = config.authURL else {
            throw AuthError.invalidURL
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let url = authURL.appendingPathComponent("verify")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": trimmedEmail,
            "token": trimmedOTP,
            "type": "email"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("無法連接到伺服器")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = parseErrorMessage(from: data)
            print("[AuthManager] Verify OTP failed: \(httpResponse.statusCode) - \(errorMsg)")
            
            // 透传服务端具体错误（过期 vs 无效 vs 其他）
            if errorMsg.lowercased().contains("expired") {
                throw AuthError.serverError(httpResponse.statusCode, String.localized(.otpExpired))
            } else {
                throw AuthError.invalidOTP
            }
        }
        
        // 解析 Token 响应
        let authSession = try parseTokenResponse(data: data, email: trimmedEmail)
        saveSession(authSession)
        
        print("[AuthManager] OTP verified, logged in as: \(trimmedEmail)")
    }
    
    // MARK: - Email + Password Flow
    
    /// 用 Email + 密码注册
    func signUp(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard isValidEmail(trimmedEmail) else {
            throw AuthError.invalidEmail
        }
        
        guard password.count >= 6 else {
            throw AuthError.invalidPassword
        }
        
        guard config.isConfigured else {
            throw AuthError.notConfigured
        }
        
        guard let authURL = config.authURL else {
            throw AuthError.invalidURL
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let url = authURL.appendingPathComponent("signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": trimmedEmail,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("無法連接到伺服器")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = parseErrorMessage(from: data)
            print("[AuthManager] Sign up failed: \(httpResponse.statusCode) - \(errorMsg)")
            throw AuthError.serverError(httpResponse.statusCode, errorMsg)
        }
        
        // 注册成功 → 不自动登入，让用户手动登入
        print("[AuthManager] Signed up successfully: \(trimmedEmail), redirecting to sign-in")
    }
    
    /// 用 Email + 密码登入
    func signIn(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard isValidEmail(trimmedEmail) else {
            throw AuthError.invalidEmail
        }
        
        guard !password.isEmpty else {
            throw AuthError.invalidPassword
        }
        
        guard config.isConfigured else {
            throw AuthError.notConfigured
        }
        
        guard let authURL = config.authURL else {
            throw AuthError.invalidURL
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var components = URLComponents(url: authURL.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": trimmedEmail,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("無法連接到伺服器")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = parseErrorMessage(from: data)
            print("[AuthManager] Sign in failed: \(httpResponse.statusCode) - \(errorMsg)")
            throw AuthError.serverError(httpResponse.statusCode, errorMsg)
        }
        
        let authSession = try parseTokenResponse(data: data, email: trimmedEmail)
        saveSession(authSession)
        
        print("[AuthManager] Signed in as: \(trimmedEmail)")
    }
    
    // MARK: - Logout
    
    /// 登出
    func signOut() async {
        print("[AuthManager] Signing out...")
        
        // 尝试通知服务器（最佳努力，不阻塞）
        if let accessToken = currentSession?.accessToken,
           let authURL = config.authURL {
            let url = authURL.appendingPathComponent("logout")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            _ = try? await performRequest(request)
        }
        
        // 清除本地 Session
        await MainActor.run {
            clearSession()
        }
        
        print("[AuthManager] Signed out successfully")
    }
    
    // MARK: - Token Refresh
    
    /// 刷新 Token
    @MainActor
    private func refreshTokenIfNeeded(refreshToken: String) async {
        guard config.isConfigured, let authURL = config.authURL else {
            clearSession()
            return
        }
        
        var components = URLComponents(url: authURL.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["refresh_token": refreshToken]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await performRequest(request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("[AuthManager] Token refresh failed, clearing session")
                clearSession()
                return
            }
            
            let newSession = try parseTokenResponse(data: data, email: currentSession?.userEmail)
            saveSession(newSession)
            print("[AuthManager] Token refreshed successfully")
            
        } catch {
            print("[AuthManager] Token refresh error: \(error)")
            clearSession()
        }
    }
    
    // MARK: - Private Helpers
    
    /// 执行网络请求
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }
    
    /// 解析 Token 响应
    private func parseTokenResponse(data: Data, email: String?) throws -> AuthSession {
        do {
            let tokenResponse = try decoder.decode(SupabaseAuthTokenResponse.self, from: data)
            
            let expiresAt: Date
            if let expiresAtTimestamp = tokenResponse.expires_at {
                expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtTimestamp))
            } else {
                expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            }
            
            return AuthSession(
                accessToken: tokenResponse.access_token,
                refreshToken: tokenResponse.refresh_token,
                expiresIn: tokenResponse.expires_in,
                expiresAt: expiresAt,
                userId: tokenResponse.user?.id ?? "",
                userEmail: tokenResponse.user?.email ?? email
            )
        } catch {
            let rawString = String(data: data, encoding: .utf8) ?? "unable to decode"
            print("[AuthManager] Token response decoding failed: \(error)")
            print("[AuthManager] Raw: \(rawString.prefix(500))")
            throw AuthError.decodingError(error.localizedDescription)
        }
    }
    
    /// 解析错误消息
    private func parseErrorMessage(from data: Data) -> String {
        if let errorResponse = try? decoder.decode(SupabaseAuthError.self, from: data) {
            return localizeErrorMessage(errorResponse.displayMessage)
        }
        return String(data: data, encoding: .utf8) ?? "未知錯誤"
    }
    
    /// 将 Supabase 英文错误映射为中文
    private func localizeErrorMessage(_ msg: String) -> String {
        let lower = msg.lowercased()
        if lower.contains("invalid login credentials") {
            return "帳號或密碼不正確"
        } else if lower.contains("user already registered") {
            return "此 Email 已註冊，請直接登入"
        } else if lower.contains("email not confirmed") {
            return "Email 尚未驗證，請查看信箱"
        } else if lower.contains("invalid email") || lower.contains("email address") && lower.contains("invalid") {
            return "Email 格式不正確"
        } else if lower.contains("password") && lower.contains("least") {
            return "密碼長度不足"
        } else if lower.contains("rate limit") || lower.contains("too many requests") {
            return "操作太頻繁，請稍後再試"
        } else if lower.contains("otp_expired") || lower.contains("expired") {
            return "驗證碼已過期，請重新發送"
        } else if lower.contains("otp_disabled") {
            return "驗證碼功能未啟用"
        } else if lower.contains("signup_disabled") {
            return "目前暫停註冊"
        }
        return msg
    }
    
    /// 验证 Email 格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    /// 设置错误消息（供 UI 显示）
    @MainActor
    func setError(_ message: String) {
        errorMessage = message
    }
    
    /// 清除错误消息
    @MainActor
    func clearError() {
        errorMessage = nil
    }
}
