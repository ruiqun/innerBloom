//
//  LocalMediaManager.swift
//  innerBloom
//
//  本机媒体管理器 - B-003, F-001
//  负责：媒体保存到本机、生成缩略图、媒体文件管理
//

import Foundation
import UIKit
import AVFoundation

/// 媒体保存结果
struct MediaSaveResult {
    let localPath: String       // 媒体文件在本机的相对路径
    let thumbnailPath: String?  // 缩略图相对路径
    let mediaType: MediaType    // 媒体类型
}

/// 媒体管理错误
enum MediaManagerError: LocalizedError {
    case failedToCreateDirectory
    case failedToSaveMedia
    case failedToGenerateThumbnail
    case invalidMediaData
    case videoTooLarge(maxSizeMB: Int)
    case unsupportedMediaType
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory:
            return "无法创建存储目录"
        case .failedToSaveMedia:
            return "媒体保存失败"
        case .failedToGenerateThumbnail:
            return "缩略图生成失败"
        case .invalidMediaData:
            return "无效的媒体数据"
        case .videoTooLarge(let maxSizeMB):
            return "影片太大，请选择小于 \(maxSizeMB)MB 的影片"
        case .unsupportedMediaType:
            return "不支持的媒体类型"
        }
    }
}

/// 本机媒体管理器
/// 单例模式，负责所有本机媒体文件的存储与管理
final class LocalMediaManager {
    
    // MARK: - Singleton
    
    static let shared = LocalMediaManager()
    
    // MARK: - Constants
    
    /// 媒体存储目录名称
    private let mediaDirectoryName = "DiaryMedia"
    /// 缩略图目录名称
    private let thumbnailDirectoryName = "Thumbnails"
    /// 最大视频文件大小 (MB)
    private let maxVideoSizeMB = 100
    /// 缩略图尺寸
    private let thumbnailSize = CGSize(width: 300, height: 300)
    /// 图片压缩质量
    private let imageCompressionQuality: CGFloat = 0.8
    
    // MARK: - Computed Properties
    
    /// Documents 目录 URL
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// 媒体存储目录 URL
    private var mediaDirectoryURL: URL {
        documentsURL.appendingPathComponent(mediaDirectoryName)
    }
    
    /// 缩略图目录 URL
    private var thumbnailDirectoryURL: URL {
        documentsURL.appendingPathComponent(thumbnailDirectoryName)
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDirectories()
    }
    
    /// 创建必要的存储目录
    private func setupDirectories() {
        let fileManager = FileManager.default
        
        do {
            // 创建媒体目录
            if !fileManager.fileExists(atPath: mediaDirectoryURL.path) {
                try fileManager.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)
                print("[LocalMediaManager] Created media directory: \(mediaDirectoryURL.path)")
            }
            
            // 创建缩略图目录
            if !fileManager.fileExists(atPath: thumbnailDirectoryURL.path) {
                try fileManager.createDirectory(at: thumbnailDirectoryURL, withIntermediateDirectories: true)
                print("[LocalMediaManager] Created thumbnail directory: \(thumbnailDirectoryURL.path)")
            }
        } catch {
            print("[LocalMediaManager] Error creating directories: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取 Documents 目录 URL
    func getDocumentsDirectory() -> URL {
        documentsURL
    }
    
    /// 保存图片到本机
    /// - Parameters:
    ///   - image: UIImage 对象
    ///   - diaryId: 日记 ID（用于文件命名）
    /// - Returns: 保存结果
    func saveImage(_ image: UIImage, for diaryId: UUID) async throws -> MediaSaveResult {
        let totalStart = CFAbsoluteTimeGetCurrent()
        print("[LocalMediaManager] 🔍 saveImage START — diaryId: \(diaryId), imageSize: \(image.size)")
        
        let quality = imageCompressionQuality
        let dirName = mediaDirectoryName
        let dirURL = mediaDirectoryURL
        let fileName = "\(diaryId.uuidString).jpg"
        let relativePath = "\(dirName)/\(fileName)"
        let fileURL = dirURL.appendingPathComponent(fileName)
        
        try await Task.detached(priority: .userInitiated) {
            let compressStart = CFAbsoluteTimeGetCurrent()
            guard let imageData = image.jpegData(compressionQuality: quality) else {
                throw MediaManagerError.invalidMediaData
            }
            print("[LocalMediaManager] 🔍 JPEG compress: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - compressStart) * 1000))ms, size: \(imageData.count / 1024)KB")
            
            do {
                let writeStart = CFAbsoluteTimeGetCurrent()
                try imageData.write(to: fileURL)
                print("[LocalMediaManager] 🔍 File write: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - writeStart) * 1000))ms")
            } catch {
                print("[LocalMediaManager] ❌ Failed to save image: \(error)")
                throw MediaManagerError.failedToSaveMedia
            }
        }.value
        
        let thumbStart = CFAbsoluteTimeGetCurrent()
        let thumbnailPath = try await generateThumbnail(from: image, for: diaryId)
        print("[LocalMediaManager] 🔍 Thumbnail generation: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - thumbStart) * 1000))ms")
        
        print("[LocalMediaManager] ✅ saveImage TOTAL: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - totalStart) * 1000))ms")
        
        return MediaSaveResult(
            localPath: relativePath,
            thumbnailPath: thumbnailPath,
            mediaType: .photo
        )
    }
    
    /// 保存视频到本机
    /// - Parameters:
    ///   - videoData: 视频数据
    ///   - diaryId: 日记 ID
    /// - Returns: 保存结果
    func saveVideo(_ videoData: Data, for diaryId: UUID) async throws -> MediaSaveResult {
        print("[LocalMediaManager] Saving video for diary: \(diaryId)")
        
        // 1. 检查视频大小
        let videoSizeMB = videoData.count / (1024 * 1024)
        if videoSizeMB > maxVideoSizeMB {
            throw MediaManagerError.videoTooLarge(maxSizeMB: maxVideoSizeMB)
        }
        
        // 2. 生成文件名
        let fileName = "\(diaryId.uuidString).mp4"
        let relativePath = "\(mediaDirectoryName)/\(fileName)"
        let fileURL = mediaDirectoryURL.appendingPathComponent(fileName)
        
        // 3. 保存视频
        do {
            try videoData.write(to: fileURL)
            print("[LocalMediaManager] Video saved: \(fileURL.path)")
        } catch {
            print("[LocalMediaManager] Failed to save video: \(error)")
            throw MediaManagerError.failedToSaveMedia
        }
        
        // 4. 生成视频缩略图
        let thumbnailPath = try await generateVideoThumbnail(from: fileURL, for: diaryId)
        
        return MediaSaveResult(
            localPath: relativePath,
            thumbnailPath: thumbnailPath,
            mediaType: .video
        )
    }
    
    /// 获取媒体文件的完整路径
    /// - Parameter relativePath: 相对路径
    /// - Returns: 完整 URL
    func getFullURL(for relativePath: String) -> URL {
        documentsURL.appendingPathComponent(relativePath)
    }
    
    /// 加载本机图片
    /// - Parameter relativePath: 相对路径
    /// - Returns: UIImage 或 nil
    func loadImage(from relativePath: String) -> UIImage? {
        let fullURL = getFullURL(for: relativePath)
        guard let data = try? Data(contentsOf: fullURL) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    /// 删除媒体文件
    /// - Parameter relativePath: 相对路径
    func deleteMedia(at relativePath: String) {
        let fullURL = getFullURL(for: relativePath)
        try? FileManager.default.removeItem(at: fullURL)
        print("[LocalMediaManager] Deleted media: \(relativePath)")
    }
    
    /// 清理所有本机媒体（用于开发/调试）
    func clearAllMedia() {
        try? FileManager.default.removeItem(at: mediaDirectoryURL)
        try? FileManager.default.removeItem(at: thumbnailDirectoryURL)
        setupDirectories()
        print("[LocalMediaManager] All media cleared")
    }
    
    // MARK: - Private Methods
    
    /// 生成图片缩略图
    private func generateThumbnail(from image: UIImage, for diaryId: UUID) async throws -> String {
        let thumbSize = thumbnailSize
        let thumbDirName = thumbnailDirectoryName
        let thumbDirURL = thumbnailDirectoryURL
        let fileName = "\(diaryId.uuidString)_thumb.jpg"
        let relativePath = "\(thumbDirName)/\(fileName)"
        let fileURL = thumbDirURL.appendingPathComponent(fileName)
        
        // 縮圖生成 + 壓縮 + 寫檔全部在背景執行緒
        try await Task.detached(priority: .utility) {
            let scale = min(thumbSize.width / image.size.width, thumbSize.height / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let thumbnail = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
                throw MediaManagerError.failedToGenerateThumbnail
            }
            do {
                try thumbnailData.write(to: fileURL)
                print("[LocalMediaManager] Thumbnail saved: \(fileURL.path)")
            } catch {
                throw MediaManagerError.failedToGenerateThumbnail
            }
        }.value
        
        return relativePath
    }
    
    /// 生成视频缩略图
    private func generateVideoThumbnail(from videoURL: URL, for diaryId: UUID) async throws -> String {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // 获取视频第一秒的帧
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: time)
            let thumbnail = UIImage(cgImage: cgImage)
            return try await generateThumbnail(from: thumbnail, for: diaryId)
        } catch {
            print("[LocalMediaManager] Failed to generate video thumbnail: \(error)")
            throw MediaManagerError.failedToGenerateThumbnail
        }
    }
}
