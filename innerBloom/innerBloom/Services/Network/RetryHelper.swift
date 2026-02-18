//
//  RetryHelper.swift
//  innerBloom
//
//  B-020: 自动重试工具
//  支持指数退避（Exponential Backoff）+ 可配置策略
//  用于上传、AI 调用、数据库操作等网络请求的自动重试
//

import Foundation

// MARK: - 重试配置

/// 重试策略配置
struct RetryConfig {
    /// 最大重试次数
    let maxRetries: Int
    
    /// 基础延迟时间（秒）
    let baseDelay: TimeInterval
    
    /// 最大延迟时间（秒）
    let maxDelay: TimeInterval
    
    /// 延迟乘数（指数退避倍率）
    let multiplier: Double
    
    /// 是否添加抖动（避免同一时间大量重试）
    let jitter: Bool
    
    /// 可重试的判断闭包（默认所有错误可重试）
    let shouldRetry: (Error) -> Bool
    
    // MARK: - 预设配置
    
    /// 默认配置：3 次重试，1s → 2s → 4s
    static let `default` = RetryConfig(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitter: true,
        shouldRetry: { _ in true }
    )
    
    /// 上传配置：3 次重试，2s → 4s → 8s（上传失败更需要间隔）
    static let upload = RetryConfig(
        maxRetries: 3,
        baseDelay: 2.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitter: true,
        shouldRetry: { error in
            // 401 未授权不重试
            if let storageError = error as? StorageServiceError {
                switch storageError {
                case .unauthorized, .notConfigured:
                    return false
                default:
                    return true
                }
            }
            return true
        }
    )
    
    /// AI 调用配置：2 次重试，3s → 6s（AI 超时比较长）
    static let ai = RetryConfig(
        maxRetries: 2,
        baseDelay: 3.0,
        maxDelay: 15.0,
        multiplier: 2.0,
        jitter: true,
        shouldRetry: { error in
            if let aiError = error as? AIServiceError {
                switch aiError {
                case .noNetwork, .cancelled:
                    return false
                case .serverError(let code, _):
                    // 4xx 客户端错误不重试（除了 429 限流）
                    return code == 429 || code >= 500 || code < 0
                default:
                    return true
                }
            }
            return true
        }
    )
    
    /// 数据库配置：3 次重试，1s → 2s → 4s
    static let database = RetryConfig(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 15.0,
        multiplier: 2.0,
        jitter: true,
        shouldRetry: { error in
            if let dbError = error as? DatabaseServiceError {
                switch dbError {
                case .unauthorized, .notConfigured, .encodingError:
                    return false
                case .requestFailed(let code):
                    // 429 限流、5xx 服务器错误可重试
                    return code == 429 || code >= 500
                default:
                    return true
                }
            }
            return true
        }
    )
}

// MARK: - 重试执行器

/// 重试工具
/// 提供带指数退避的自动重试能力
enum RetryHelper {
    
    /// 带自动重试执行异步操作
    /// - Parameters:
    ///   - config: 重试配置
    ///   - operation: 要执行的异步操作
    /// - Returns: 操作结果
    /// - Throws: 最后一次失败的错误
    static func withRetry<T>(
        config: RetryConfig? = nil,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let effectiveConfig = config ?? RetryConfig.default
        var lastError: Error?
        
        for attempt in 0...effectiveConfig.maxRetries {
            do {
                let result = try await operation()
                
                // 如果之前有重试，打印成功日志
                if attempt > 0 {
                    print("[RetryHelper] ✅ Succeeded on attempt \(attempt + 1)/\(effectiveConfig.maxRetries + 1)")
                }
                
                return result
            } catch {
                lastError = error
                
                // 检查是否应该重试
                guard attempt < effectiveConfig.maxRetries && effectiveConfig.shouldRetry(error) else {
                    if attempt >= effectiveConfig.maxRetries {
                        print("[RetryHelper] ❌ All \(effectiveConfig.maxRetries + 1) attempts failed")
                    } else {
                        print("[RetryHelper] ❌ Error not retryable: \(error.localizedDescription)")
                    }
                    throw error
                }
                
                // 计算延迟时间（指数退避）
                let delay = calculateDelay(attempt: attempt, config: effectiveConfig)
                
                print("[RetryHelper] ⚠️ Attempt \(attempt + 1)/\(effectiveConfig.maxRetries + 1) failed: \(error.localizedDescription)")
                print("[RetryHelper] 🔄 Retrying in \(String(format: "%.1f", delay))s...")
                
                // 等待指定时间后重试
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NSError(domain: "RetryHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown retry error"])
    }
    
    /// 计算指数退避延迟时间
    /// - Parameters:
    ///   - attempt: 当前尝试次数（从 0 开始）
    ///   - config: 重试配置
    /// - Returns: 延迟秒数
    private static func calculateDelay(attempt: Int, config: RetryConfig) -> TimeInterval {
        // 指数退避：baseDelay * multiplier^attempt
        let exponentialDelay = config.baseDelay * pow(config.multiplier, Double(attempt))
        
        // 限制最大延迟
        var delay = min(exponentialDelay, config.maxDelay)
        
        // 添加抖动（±25%）避免雷鸣群效应
        if config.jitter {
            let jitterRange = delay * 0.25
            delay += Double.random(in: -jitterRange...jitterRange)
            delay = max(0.1, delay) // 至少 0.1s
        }
        
        return delay
    }
}
