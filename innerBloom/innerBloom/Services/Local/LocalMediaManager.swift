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
    
    // MARK: - Two-Tier Image Cache (Memory + Disk)
    
    /// L1: in-memory cache (fast, cleared on app terminate / memory pressure)
    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()
    
    /// L2: persistent disk cache directory (Caches/ThumbCache)
    private var thumbCacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("ThumbCache")
    }
    
    /// Optimized thumbnail size for list items (56pt * 3x = 168px)
    private let thumbCacheSize: CGFloat = 168
    
    /// L2: persistent display-resolution cache directory (Caches/DisplayCache)
    private var displayCacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("DisplayCache")
    }
    
    /// Display-optimized size for detail view headers (screen width at 3x)
    private let displayCacheSize: CGFloat = 1500
    
    /// Load image with two-tier cache. Returns cached UIImage if available.
    func cachedImage(forPath relativePath: String) -> UIImage? {
        let key = relativePath as NSString
        touchAccessLog(relativePath)
        
        // L1: memory
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        
        // L2: disk cache (small optimized thumbnail)
        let diskPath = thumbCachePath(for: relativePath)
        if let cached = UIImage(contentsOfFile: diskPath) {
            memoryCache.setObject(cached, forKey: key)
            return cached
        }
        
        // L3: original file → generate disk cache entry
        let fullPath = getDocumentsDirectory().appendingPathComponent(relativePath).path
        guard let original = UIImage(contentsOfFile: fullPath) else { return nil }
        
        let thumb = downsample(original, to: thumbCacheSize)
        memoryCache.setObject(thumb, forKey: key)
        saveToDiskCache(thumb, for: relativePath)
        return thumb
    }
    
    /// Load display-resolution image with three-tier cache (memory → disk → original)
    func cachedFullImage(forPath relativePath: String) -> UIImage? {
        let key = ("full:" + relativePath) as NSString
        touchAccessLog(relativePath)
        
        // L1: memory
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        
        // L2: display-resolution disk cache
        let diskPath = displayCachePath(for: relativePath)
        if let cached = UIImage(contentsOfFile: diskPath) {
            memoryCache.setObject(cached, forKey: key)
            return cached
        }
        
        // L3: original file → generate display cache entry
        let fullPath = getDocumentsDirectory().appendingPathComponent(relativePath).path
        guard let original = UIImage(contentsOfFile: fullPath) else { return nil }
        
        let display = downsample(original, to: displayCacheSize)
        memoryCache.setObject(display, forKey: key)
        saveToDisplayCache(display, for: relativePath)
        return display
    }
    
    /// Remove cached images for a specific path
    func removeCachedImage(forPath relativePath: String) {
        memoryCache.removeObject(forKey: relativePath as NSString)
        memoryCache.removeObject(forKey: ("full:" + relativePath) as NSString)
        let diskPath = thumbCachePath(for: relativePath)
        try? FileManager.default.removeItem(atPath: diskPath)
        let displayPath = displayCachePath(for: relativePath)
        try? FileManager.default.removeItem(atPath: displayPath)
    }
    
    /// Memory-only lookup for full images (no disk I/O, safe for synchronous init calls)
    func fullImageFromMemory(forPath relativePath: String) -> UIImage? {
        let key = ("full:" + relativePath) as NSString
        return memoryCache.object(forKey: key)
    }
    
    /// Memory-only lookup for thumbnails (no disk I/O, safe for synchronous init calls)
    func thumbnailFromMemory(forPath relativePath: String) -> UIImage? {
        return memoryCache.object(forKey: relativePath as NSString)
    }
    
    /// Download image from URL, save locally, and warm all cache tiers
    func downloadAndCache(from urlString: String, toRelativePath relativePath: String) async -> UIImage? {
        let fullKey = ("full:" + relativePath) as NSString
        if let cached = memoryCache.object(forKey: fullKey) {
            return cached
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            
            let fm = FileManager.default
            let fileURL = getFullURL(for: relativePath)
            let dirURL = fileURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: dirURL.path) {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }
            try data.write(to: fileURL)
            
            let display = downsample(image, to: displayCacheSize)
            memoryCache.setObject(display, forKey: fullKey)
            saveToDisplayCache(display, for: relativePath)
            
            let thumbKey = relativePath as NSString
            let thumb = downsample(image, to: thumbCacheSize)
            memoryCache.setObject(thumb, forKey: thumbKey)
            saveToDiskCache(thumb, for: relativePath)
            
            touchAccessLog(relativePath)
            print("[LocalMediaManager] ✅ Downloaded and cached: \(relativePath)")
            
            return display
        } catch {
            print("[LocalMediaManager] ❌ downloadAndCache failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Disk Cache Helpers
    
    private func thumbCachePath(for relativePath: String) -> String {
        let safeName = relativePath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return thumbCacheURL.appendingPathComponent(safeName).path
    }
    
    private func saveToDiskCache(_ image: UIImage, for relativePath: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: thumbCacheURL.path) {
            try? fm.createDirectory(at: thumbCacheURL, withIntermediateDirectories: true)
        }
        let path = thumbCachePath(for: relativePath)
        if let data = image.jpegData(compressionQuality: 0.75) {
            fm.createFile(atPath: path, contents: data)
        }
    }
    
    private func displayCachePath(for relativePath: String) -> String {
        let safeName = relativePath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return displayCacheURL.appendingPathComponent(safeName).path
    }
    
    private func saveToDisplayCache(_ image: UIImage, for relativePath: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: displayCacheURL.path) {
            try? fm.createDirectory(at: displayCacheURL, withIntermediateDirectories: true)
        }
        let path = displayCachePath(for: relativePath)
        if let data = image.jpegData(compressionQuality: 0.85) {
            fm.createFile(atPath: path, contents: data)
        }
    }
    
    private func downsample(_ image: UIImage, to maxDimension: CGFloat) -> UIImage {
        let size = image.size
        if max(size.width, size.height) <= maxDimension { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
    
    // MARK: - Storage Limits
    
    /// Max offline content size (1 GB)
    private let maxStorageBytes: Int64 = 1_024 * 1_024 * 1_024
    /// Clean down to this target (90%) to avoid marginal thrashing
    private let targetStorageBytes: Int64 = 900 * 1_024 * 1_024
    /// Files idle longer than this are priority eviction candidates
    private let maxIdleDays: TimeInterval = 7 * 24 * 3600
    /// Minimum interval between cleanup scans (6 hours)
    private let cleanupCooldown: TimeInterval = 6 * 3600
    /// UserDefaults key for last cleanup timestamp
    private let lastCleanupKey = "com.innerbloom.lastStorageCleanup"
    /// Access log persistence path
    private var accessLogURL: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return lib.appendingPathComponent("media_access_log.plist")
    }
    /// In-memory access log: relativePath → last access date
    private var accessLog: [String: Date] = [:]
    private let accessLogQueue = DispatchQueue(label: "com.innerbloom.accesslog")
    
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
        loadAccessLog()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performStorageCleanupIfNeeded()
        }
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
        
        touchAccessLog(relativePath)
        touchAccessLog(thumbnailPath)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performStorageCleanupIfNeeded()
        }
        
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
        
        touchAccessLog(relativePath)
        touchAccessLog(thumbnailPath)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performStorageCleanupIfNeeded()
        }
        
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
        removeCachedImage(forPath: relativePath)
        accessLogQueue.async { [weak self] in
            self?.accessLog.removeValue(forKey: relativePath)
        }
        print("[LocalMediaManager] Deleted media: \(relativePath)")
    }
    
    /// Persist access log to disk (call when app enters background)
    func flushAccessLog() {
        persistAccessLog()
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
    
    // MARK: - Storage Cleanup (LRU + 7-day idle eviction, 1 GB cap)
    
    private func touchAccessLog(_ relativePath: String) {
        accessLogQueue.async { [weak self] in
            self?.accessLog[relativePath] = Date()
        }
    }
    
    private func loadAccessLog() {
        guard let data = try? Data(contentsOf: accessLogURL),
              let dict = try? PropertyListDecoder().decode([String: Date].self, from: data) else { return }
        accessLog = dict
    }
    
    private func persistAccessLog() {
        accessLogQueue.async { [weak self] in
            guard let self else { return }
            if let data = try? PropertyListEncoder().encode(self.accessLog) {
                try? data.write(to: self.accessLogURL, options: .atomic)
            }
        }
    }
    
    /// Calculate total bytes used by DiaryMedia/ + Thumbnails/
    func totalOfflineStorageBytes() -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        for dir in [mediaDirectoryURL, thumbnailDirectoryURL] {
            if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
                }
            }
        }
        return total
    }
    
    /// Run cleanup if storage exceeds 1 GB. Respects cooldown to avoid redundant scans.
    /// Cleans down to 90% (900 MB) to create a buffer against marginal thrashing.
    func performStorageCleanupIfNeeded() {
        // Cooldown: skip if last cleanup was within 6 hours
        let lastCleanup = UserDefaults.standard.double(forKey: lastCleanupKey)
        if lastCleanup > 0 && Date().timeIntervalSince1970 - lastCleanup < cleanupCooldown {
            return
        }
        
        let totalBytes = totalOfflineStorageBytes()
        guard totalBytes > maxStorageBytes else {
            persistAccessLog()
            return
        }
        
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCleanupKey)
        print("[LocalMediaManager] 🧹 Storage \(totalBytes / 1_048_576)MB > \(maxStorageBytes / 1_048_576)MB, cleaning to \(targetStorageBytes / 1_048_576)MB…")
        
        let fm = FileManager.default
        let now = Date()
        
        struct FileEntry {
            let url: URL
            let relativePath: String
            let size: Int64
            let lastAccess: Date
            var isIdle: Bool
        }
        
        var files: [FileEntry] = []
        
        for dir in [mediaDirectoryURL, thumbnailDirectoryURL] {
            let dirName = dir.lastPathComponent
            if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else { continue }
                    let relative = "\(dirName)/\(fileURL.lastPathComponent)"
                    let lastAccess = accessLog[relative] ?? (try? fm.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date) ?? .distantPast
                    let idle = now.timeIntervalSince(lastAccess) > maxIdleDays
                    files.append(FileEntry(url: fileURL, relativePath: relative, size: Int64(size), lastAccess: lastAccess, isIdle: idle))
                }
            }
        }
        
        // Phase 1: evict 7-day-idle files first (oldest access first)
        let idleFiles = files.filter { $0.isIdle }.sorted { $0.lastAccess < $1.lastAccess }
        let activeFiles = files.filter { !$0.isIdle }.sorted { $0.lastAccess < $1.lastAccess }
        let sortedFiles = idleFiles + activeFiles
        
        var currentTotal = totalBytes
        var deletedCount = 0
        
        for file in sortedFiles {
            guard currentTotal > targetStorageBytes else { break }
            
            try? fm.removeItem(at: file.url)
            removeCachedImage(forPath: file.relativePath)
            accessLogQueue.sync {
                _ = accessLog.removeValue(forKey: file.relativePath)
            }
            currentTotal -= file.size
            deletedCount += 1
        }
        
        persistAccessLog()
        print("[LocalMediaManager] 🧹 Deleted \(deletedCount) files, storage now \(currentTotal / 1_048_576)MB")
    }
}
