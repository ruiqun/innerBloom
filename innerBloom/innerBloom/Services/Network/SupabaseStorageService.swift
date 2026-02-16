//
//  SupabaseStorageService.swift
//  innerBloom
//
//  Supabase Storage 服务 - B-004
//  负责：媒体文件上传到 Supabase Storage、获取云端路径
//

import Foundation
import UIKit

/// Storage 上传结果
struct StorageUploadResult {
    let bucket: String      // Bucket 名称
    let path: String        // 文件在 Bucket 中的路径
    let publicURL: URL?     // 公开访问 URL
}

/// Storage 服务错误
enum StorageServiceError: LocalizedError, Equatable {
    case notConfigured
    case invalidURL
    case uploadFailed(statusCode: Int)
    case networkError(String)
    case fileNotFound
    case invalidResponse
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase 未配置，请先设置项目 URL 和 Key"
        case .invalidURL:
            return "无效的 URL"
        case .uploadFailed(let code):
            return "上传失败（错误码：\(code)）"
        case .networkError(let message):
            return "网络错误：\(message)"
        case .fileNotFound:
            return "文件不存在"
        case .invalidResponse:
            return "服务器响应无效"
        case .unauthorized:
            return "未授权，请检查 API Key"
        }
    }
    
    static func == (lhs: StorageServiceError, rhs: StorageServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.invalidURL, .invalidURL),
             (.fileNotFound, .fileNotFound),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized):
            return true
        case (.uploadFailed(let l), .uploadFailed(let r)):
            return l == r
        case (.networkError(let l), .networkError(let r)):
            return l == r
        default:
            return false
        }
    }
}

/// Supabase Storage 服务
/// 单例模式，负责所有媒体文件的云端上传
/// B-019: 支援多用戶隔離（路徑加入 user_id 前綴、使用 user JWT 認證）
final class SupabaseStorageService {
    
    // MARK: - Singleton
    
    static let shared = SupabaseStorageService()
    
    // MARK: - Dependencies
    
    private let config = SupabaseConfig.shared
    private let session: URLSession
    
    // MARK: - Initialization
    
    private init() {
        // 配置 URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300 // 5 分钟超时（大文件上传）
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - B-019 Auth Helpers（多用戶隔離）
    
    /// 取得當前登入使用者的 Access Token
    private func getAccessToken() async throws -> String {
        guard let token = await AuthManager.shared.getValidAccessToken() else {
            print("[StorageService] ⚠️ No valid access token")
            throw StorageServiceError.unauthorized
        }
        return token
    }
    
    /// 取得當前登入使用者的 user_id（用於路徑前綴）
    private var currentUserId: String? {
        AuthManager.shared.currentUserId
    }
    
    /// 為檔案路徑加上 user_id 前綴（D-016: {user_id}/{type}/{diaryId}.ext）
    /// 如果未登入則不加前綴（向前兼容）
    private func userPrefixedPath(_ path: String) -> String {
        guard let userId = currentUserId else {
            print("[StorageService] ⚠️ No user_id available, using path without prefix")
            return path
        }
        return "\(userId)/\(path)"
    }
    
    // MARK: - Public Methods
    
    /// 上传图片到 Storage
    /// - Parameters:
    ///   - image: UIImage 对象
    ///   - diaryId: 日记 ID（用于文件命名）
    ///   - compressionQuality: 压缩质量 (0-1)
    /// - Returns: 上传结果
    func uploadImage(_ image: UIImage, for diaryId: UUID, compressionQuality: CGFloat = 0.8) async throws -> StorageUploadResult {
        print("[StorageService] Uploading image for diary: \(diaryId)")
        
        // 1. 检查配置
        guard config.isConfigured else {
            throw StorageServiceError.notConfigured
        }
        
        // 2. 压缩图片
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw StorageServiceError.invalidResponse
        }
        
        // 3. 生成文件路径（B-019: 加入 user_id 前綴）
        let fileName = "\(diaryId.uuidString).jpg"
        let filePath = userPrefixedPath("images/\(fileName)")
        
        // 4. 上传
        return try await uploadFile(
            data: imageData,
            bucket: config.mediaBucketName,
            path: filePath,
            contentType: "image/jpeg"
        )
    }
    
    /// 上传视频到 Storage
    /// - Parameters:
    ///   - videoData: 视频数据
    ///   - diaryId: 日记 ID
    /// - Returns: 上传结果
    func uploadVideo(_ videoData: Data, for diaryId: UUID) async throws -> StorageUploadResult {
        print("[StorageService] Uploading video for diary: \(diaryId)")
        
        // 1. 检查配置
        guard config.isConfigured else {
            throw StorageServiceError.notConfigured
        }
        
        // 2. 生成文件路径（B-019: 加入 user_id 前綴）
        let fileName = "\(diaryId.uuidString).mp4"
        let filePath = userPrefixedPath("videos/\(fileName)")
        
        // 3. 上传
        return try await uploadFile(
            data: videoData,
            bucket: config.mediaBucketName,
            path: filePath,
            contentType: "video/mp4"
        )
    }
    
    /// 上传缩略图到 Storage
    /// - Parameters:
    ///   - image: 缩略图
    ///   - diaryId: 日记 ID
    /// - Returns: 上传结果
    func uploadThumbnail(_ image: UIImage, for diaryId: UUID) async throws -> StorageUploadResult {
        print("[StorageService] Uploading thumbnail for diary: \(diaryId)")
        
        // 1. 检查配置
        guard config.isConfigured else {
            throw StorageServiceError.notConfigured
        }
        
        // 2. 压缩缩略图
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageServiceError.invalidResponse
        }
        
        // 3. 生成文件路径（B-019: 加入 user_id 前綴）
        let fileName = "\(diaryId.uuidString)_thumb.jpg"
        let filePath = userPrefixedPath("thumbnails/\(fileName)")
        
        // 4. 上传
        return try await uploadFile(
            data: imageData,
            bucket: config.thumbnailBucketName,
            path: filePath,
            contentType: "image/jpeg"
        )
    }
    
    /// 从本机路径上传文件
    /// - Parameters:
    ///   - localPath: 本机相对路径
    ///   - diaryId: 日记 ID
    ///   - mediaType: 媒体类型
    /// - Returns: 上传结果
    func uploadFromLocalPath(_ localPath: String, for diaryId: UUID, mediaType: MediaType) async throws -> StorageUploadResult {
        let localMediaManager = LocalMediaManager.shared
        let fullURL = localMediaManager.getFullURL(for: localPath)
        
        guard FileManager.default.fileExists(atPath: fullURL.path) else {
            throw StorageServiceError.fileNotFound
        }
        
        let data = try Data(contentsOf: fullURL)
        
        switch mediaType {
        case .photo:
            guard let image = UIImage(data: data) else {
                throw StorageServiceError.invalidResponse
            }
            return try await uploadImage(image, for: diaryId)
            
        case .video:
            return try await uploadVideo(data, for: diaryId)
        }
    }
    
    /// 删除云端文件
    /// B-019: RLS 確保只能刪除本人檔案
    /// - Parameters:
    ///   - bucket: Bucket 名称
    ///   - path: 文件路径
    func deleteFile(bucket: String, path: String) async throws {
        print("[StorageService] Deleting file: \(bucket)/\(path)")
        
        guard config.isConfigured else {
            throw StorageServiceError.notConfigured
        }
        
        guard let storageURL = config.storageURL else {
            throw StorageServiceError.invalidURL
        }
        
        let url = storageURL.appendingPathComponent("object/\(bucket)/\(path)")
        let token = try await getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageServiceError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw StorageServiceError.uploadFailed(statusCode: httpResponse.statusCode)
        }
        
        print("[StorageService] File deleted successfully")
    }
    
    // MARK: - Private Methods
    
    /// 通用文件上传方法
    /// B-019: 使用 user JWT 認證，Storage RLS 驗證路徑歸屬
    private func uploadFile(data: Data, bucket: String, path: String, contentType: String) async throws -> StorageUploadResult {
        guard let storageURL = config.storageURL else {
            throw StorageServiceError.invalidURL
        }
        
        // 构建上传 URL
        let uploadURL = storageURL.appendingPathComponent("object/\(bucket)/\(path)")
        let token = try await getAccessToken()
        
        // 构建请求（B-019: 使用 user JWT）
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data
        
        print("[StorageService] Uploading to: \(uploadURL)")
        print("[StorageService] File size: \(data.count / 1024) KB")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StorageServiceError.invalidResponse
            }
            
            print("[StorageService] Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200, 201:
                // 成功
                let publicURL = config.publicURL(bucket: bucket, path: path)
                print("[StorageService] Upload successful: \(publicURL?.absoluteString ?? "N/A")")
                
                return StorageUploadResult(
                    bucket: bucket,
                    path: path,
                    publicURL: publicURL
                )
                
            case 401:
                throw StorageServiceError.unauthorized
                
            default:
                throw StorageServiceError.uploadFailed(statusCode: httpResponse.statusCode)
            }
            
        } catch let error as StorageServiceError {
            throw error
        } catch {
            throw StorageServiceError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Batch Upload

extension SupabaseStorageService {
    
    /// 批量上传结果
    struct BatchUploadResult {
        let mediaResult: StorageUploadResult?
        let thumbnailResult: StorageUploadResult?
        let errors: [Error]
    }
    
    /// 批量上传媒体和缩略图
    /// - Parameters:
    ///   - localMediaPath: 本机媒体路径
    ///   - localThumbnailPath: 本机缩略图路径
    ///   - diaryId: 日记 ID
    ///   - mediaType: 媒体类型
    /// - Returns: 批量上传结果
    func uploadMediaWithThumbnail(
        localMediaPath: String,
        localThumbnailPath: String?,
        diaryId: UUID,
        mediaType: MediaType
    ) async -> BatchUploadResult {
        var mediaResult: StorageUploadResult?
        var thumbnailResult: StorageUploadResult?
        var errors: [Error] = []
        
        // 1. 上传媒体
        do {
            mediaResult = try await uploadFromLocalPath(localMediaPath, for: diaryId, mediaType: mediaType)
        } catch {
            errors.append(error)
            print("[StorageService] Media upload failed: \(error)")
        }
        
        // 2. 上传缩略图
        if let thumbPath = localThumbnailPath {
            do {
                let localMediaManager = LocalMediaManager.shared
                let thumbURL = localMediaManager.getFullURL(for: thumbPath)
                
                if let thumbData = try? Data(contentsOf: thumbURL),
                   let thumbImage = UIImage(data: thumbData) {
                    thumbnailResult = try await uploadThumbnail(thumbImage, for: diaryId)
                }
            } catch {
                errors.append(error)
                print("[StorageService] Thumbnail upload failed: \(error)")
            }
        }
        
        return BatchUploadResult(
            mediaResult: mediaResult,
            thumbnailResult: thumbnailResult,
            errors: errors
        )
    }
}
