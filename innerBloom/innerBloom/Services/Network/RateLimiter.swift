//
//  RateLimiter.swift
//  innerBloom
//
//  B-020: 客户端用量保护（Rate Limiter）
//  防止同一使用者短时间内大量发送请求
//  用于 AI 聊天、上传、搜索等重要操作
//

import Foundation

// MARK: - 限流结果

/// 限流检查结果
enum RateLimitResult {
    case allowed                        // 允许执行
    case limited(retryAfter: TimeInterval) // 被限流，附带建议等待时间
    
    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
    
    var retryAfterSeconds: TimeInterval? {
        if case .limited(let seconds) = self { return seconds }
        return nil
    }
}

// MARK: - 限流器

/// 客户端限流器
/// 使用滑动窗口算法（Sliding Window）控制请求频率
/// 线程安全：使用 actor 保证并发安全
actor RateLimiter {
    
    // MARK: - 配置
    
    /// 时间窗口大小（秒）
    private let windowSize: TimeInterval
    
    /// 窗口内允许的最大请求数
    private let maxRequests: Int
    
    /// 请求时间戳记录
    private var requestTimestamps: [Date] = []
    
    /// 限流器名称（用于日志）
    private let name: String
    
    // MARK: - 预设实例
    
    /// AI 聊天限流：每 10 秒最多 5 条消息
    static let aiChat = RateLimiter(name: "AIChat", windowSize: 10, maxRequests: 5)
    
    /// AI 分析限流：每 30 秒最多 3 次分析
    static let aiAnalysis = RateLimiter(name: "AIAnalysis", windowSize: 30, maxRequests: 3)
    
    /// 上传限流：每 60 秒最多 5 次上传
    static let upload = RateLimiter(name: "Upload", windowSize: 60, maxRequests: 5)
    
    /// 搜索限流：每 5 秒最多 3 次搜索
    static let search = RateLimiter(name: "Search", windowSize: 5, maxRequests: 3)
    
    /// 保存限流：每 10 秒最多 3 次保存
    static let save = RateLimiter(name: "Save", windowSize: 10, maxRequests: 3)
    
    // MARK: - 初始化
    
    init(name: String, windowSize: TimeInterval, maxRequests: Int) {
        self.name = name
        self.windowSize = windowSize
        self.maxRequests = maxRequests
    }
    
    // MARK: - 公开方法
    
    /// 检查是否允许新请求
    /// - Returns: 限流检查结果
    func checkLimit() -> RateLimitResult {
        cleanOldTimestamps()
        
        if requestTimestamps.count < maxRequests {
            return .allowed
        }
        
        // 计算需要等待的时间
        guard let oldest = requestTimestamps.first else {
            return .allowed
        }
        
        let retryAfter = oldest.addingTimeInterval(windowSize).timeIntervalSinceNow
        let waitTime = max(0.5, retryAfter)
        
        print("[RateLimiter:\(name)] ⚠️ Rate limited: \(requestTimestamps.count)/\(maxRequests) in \(windowSize)s, retry after \(String(format: "%.1f", waitTime))s")
        
        return .limited(retryAfter: waitTime)
    }
    
    /// 记录一次请求
    func recordRequest() {
        cleanOldTimestamps()
        requestTimestamps.append(Date())
    }
    
    /// 检查并记录请求（原子操作）
    /// - Returns: 限流检查结果
    func checkAndRecord() -> RateLimitResult {
        let result = checkLimit()
        if case .allowed = result {
            recordRequest()
        }
        return result
    }
    
    /// 重置限流器
    func reset() {
        requestTimestamps.removeAll()
    }
    
    /// 当前窗口内的请求数
    var currentCount: Int {
        cleanOldTimestamps()
        return requestTimestamps.count
    }
    
    // MARK: - 私有方法
    
    /// 清理过期的时间戳
    private func cleanOldTimestamps() {
        let cutoff = Date().addingTimeInterval(-windowSize)
        requestTimestamps.removeAll { $0 < cutoff }
    }
}

// MARK: - 便捷扩展

extension RateLimiter {
    
    /// 等待限流通过后执行操作
    /// - Parameter operation: 要执行的操作
    /// - Returns: 操作结果
    func executeWithLimit<T>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let result = checkAndRecord()
        
        switch result {
        case .allowed:
            return try await operation()
            
        case .limited(let retryAfter):
            print("[RateLimiter:\(name)] 🕐 Waiting \(String(format: "%.1f", retryAfter))s before executing...")
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            
            // 等待后重新检查
            let secondCheck = checkAndRecord()
            guard case .allowed = secondCheck else {
                throw RateLimitError.tooManyRequests(retryAfter: retryAfter)
            }
            
            return try await operation()
        }
    }
}

// MARK: - 限流错误

/// 限流错误
enum RateLimitError: LocalizedError {
    case tooManyRequests(retryAfter: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .tooManyRequests(let seconds):
            return "操作过于频繁，请 \(Int(seconds)) 秒后再试"
        }
    }
}
