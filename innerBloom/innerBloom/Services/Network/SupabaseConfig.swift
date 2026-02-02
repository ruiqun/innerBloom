//
//  SupabaseConfig.swift
//  innerBloom
//
//  Supabase 配置管理 - B-004
//  负责：Supabase 连接配置、环境管理
//

import Foundation

/// Supabase 配置
/// 使用单例模式管理全局配置
final class SupabaseConfig {
    
    // MARK: - Singleton
    
    static let shared = SupabaseConfig()
    
    // MARK: - Configuration Keys
    
    /// Supabase 项目 URL
    /// ⚠️ 请在首次使用前设置正确的值
    var projectURL: String {
        // 优先从环境变量读取（用于 CI/CD）
        if let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            return envURL
        }
        // 否则使用配置文件中的值
        return _projectURL
    }
    
    /// Supabase anon key（公开密钥，可以放在客户端）
    /// ⚠️ 请在首次使用前设置正确的值
    var anonKey: String {
        // 优先从环境变量读取
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] {
            return envKey
        }
        return _anonKey
    }
    
    // MARK: - Storage Configuration
    
    /// 媒体存储 Bucket 名称
    let mediaBucketName = "diary-media"
    
    /// 缩略图存储 Bucket 名称
    let thumbnailBucketName = "diary-thumbnails"
    
    // MARK: - Private Storage
    
    /// 项目 URL（内部存储）
    /// ⚠️ TODO: 替换为你的 Supabase 项目 URL
    private var _projectURL: String = "https://your-project.supabase.co"
    
    /// Anon Key（内部存储）
    /// ⚠️ TODO: 替换为你的 Supabase anon key
    private var _anonKey: String = "your-anon-key"
    
    // MARK: - Initialization
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Methods
    
    /// 从本地配置文件加载（如果存在）
    private func loadConfiguration() {
        // 尝试从 Supabase.plist 加载配置
        if let plistPath = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
           let plistData = FileManager.default.contents(atPath: plistPath),
           let config = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: String] {
            
            if let url = config["SUPABASE_URL"], !url.isEmpty {
                _projectURL = url
            }
            if let key = config["SUPABASE_ANON_KEY"], !key.isEmpty {
                _anonKey = key
            }
            print("[SupabaseConfig] Loaded configuration from Supabase.plist")
        }
    }
    
    /// 手动设置配置（用于测试或动态配置）
    func configure(projectURL: String, anonKey: String) {
        _projectURL = projectURL
        _anonKey = anonKey
        print("[SupabaseConfig] Configuration updated")
    }
    
    /// 检查配置是否有效
    var isConfigured: Bool {
        !_projectURL.contains("your-project") && !_anonKey.contains("your-anon-key")
    }
    
    // MARK: - URL Builders
    
    /// 获取 Storage API URL
    var storageURL: URL? {
        URL(string: "\(projectURL)/storage/v1")
    }
    
    /// 获取 REST API URL
    var restURL: URL? {
        URL(string: "\(projectURL)/rest/v1")
    }
    
    /// 获取 Auth API URL
    var authURL: URL? {
        URL(string: "\(projectURL)/auth/v1")
    }
    
    /// 构建媒体文件的公开 URL
    /// - Parameters:
    ///   - bucket: Bucket 名称
    ///   - path: 文件路径
    /// - Returns: 公开访问 URL
    func publicURL(bucket: String, path: String) -> URL? {
        URL(string: "\(projectURL)/storage/v1/object/public/\(bucket)/\(path)")
    }
}

// MARK: - Debug Helpers

extension SupabaseConfig {
    /// 打印当前配置（用于调试，隐藏敏感信息）
    func printDebugInfo() {
        print("[SupabaseConfig] Debug Info:")
        print("  - Project URL: \(projectURL)")
        print("  - Anon Key: \(String(anonKey.prefix(10)))...")
        print("  - Is Configured: \(isConfigured)")
        print("  - Media Bucket: \(mediaBucketName)")
        print("  - Thumbnail Bucket: \(thumbnailBucketName)")
    }
}
