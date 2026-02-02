//
//  B003_MediaAndDraftTests.swift
//  innerBloomTests
//
//  B-003 测试用例：选媒体与本机草稿保存
//  覆盖功能：F-001（选媒体）、D-001（日记清单）、D-002（用户输入）
//

import XCTest
import UIKit
@testable import innerBloom

// MARK: - LocalMediaManager 测试

final class LocalMediaManagerTests: XCTestCase {
    
    var mediaManager: LocalMediaManager!
    
    override func setUp() {
        super.setUp()
        mediaManager = LocalMediaManager.shared
    }
    
    override func tearDown() {
        // 清理测试产生的文件
        mediaManager.clearAllMedia()
        super.tearDown()
    }
    
    // MARK: - 图片保存测试
    
    /// 测试：成功保存图片
    /// 预期：返回有效的本机路径和缩略图路径
    func testSaveImage_Success() async throws {
        // Given
        let testImage = createTestImage(color: .red, size: CGSize(width: 100, height: 100))
        let diaryId = UUID()
        
        // When
        let result = try await mediaManager.saveImage(testImage, for: diaryId)
        
        // Then
        XCTAssertFalse(result.localPath.isEmpty, "本机路径不应为空")
        XCTAssertNotNil(result.thumbnailPath, "缩略图路径不应为空")
        XCTAssertEqual(result.mediaType, .photo, "媒体类型应为照片")
        XCTAssertTrue(result.localPath.contains(diaryId.uuidString), "路径应包含日记 ID")
    }
    
    /// 测试：保存的图片可以被正确加载
    func testSaveAndLoadImage() async throws {
        // Given
        let testImage = createTestImage(color: .blue, size: CGSize(width: 200, height: 200))
        let diaryId = UUID()
        
        // When
        let result = try await mediaManager.saveImage(testImage, for: diaryId)
        let loadedImage = mediaManager.loadImage(from: result.localPath)
        
        // Then
        XCTAssertNotNil(loadedImage, "应能加载保存的图片")
    }
    
    /// 测试：获取完整 URL
    func testGetFullURL() {
        // Given
        let relativePath = "DiaryMedia/test.jpg"
        
        // When
        let fullURL = mediaManager.getFullURL(for: relativePath)
        
        // Then
        XCTAssertTrue(fullURL.path.contains("Documents"), "完整路径应包含 Documents")
        XCTAssertTrue(fullURL.path.hasSuffix(relativePath), "完整路径应以相对路径结尾")
    }
    
    /// 测试：删除媒体文件
    func testDeleteMedia() async throws {
        // Given
        let testImage = createTestImage(color: .green, size: CGSize(width: 50, height: 50))
        let diaryId = UUID()
        let result = try await mediaManager.saveImage(testImage, for: diaryId)
        
        // When
        mediaManager.deleteMedia(at: result.localPath)
        let loadedImage = mediaManager.loadImage(from: result.localPath)
        
        // Then
        XCTAssertNil(loadedImage, "删除后不应能加载图片")
    }
    
    // MARK: - 视频保存测试
    
    /// 测试：视频太大时抛出错误
    func testSaveVideo_TooLarge() async {
        // Given
        let diaryId = UUID()
        // 创建超过 100MB 的假数据
        let largeData = Data(repeating: 0, count: 101 * 1024 * 1024)
        
        // When/Then
        do {
            _ = try await mediaManager.saveVideo(largeData, for: diaryId)
            XCTFail("应抛出视频过大错误")
        } catch let error as MediaManagerError {
            if case .videoTooLarge(let maxSize) = error {
                XCTAssertEqual(maxSize, 100, "最大限制应为 100MB")
            } else {
                XCTFail("应为 videoTooLarge 错误")
            }
        } catch {
            XCTFail("应为 MediaManagerError 类型")
        }
    }
    
    // MARK: - Helper
    
    private func createTestImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - LocalDraftManager 测试

final class LocalDraftManagerTests: XCTestCase {
    
    var draftManager: LocalDraftManager!
    
    override func setUp() {
        super.setUp()
        draftManager = LocalDraftManager.shared
        // 清理之前的测试数据
        draftManager.clearAllDrafts()
    }
    
    override func tearDown() {
        draftManager.clearAllDrafts()
        super.tearDown()
    }
    
    // MARK: - 草稿保存测试
    
    /// 测试：成功保存草稿
    func testSaveDraft_Success() throws {
        // Given
        let entry = DiaryEntry(mediaType: .photo, localMediaPath: "test/path.jpg")
        
        // When
        try draftManager.saveDraft(entry)
        
        // Then
        XCTAssertTrue(draftManager.hasDrafts(), "应有草稿存在")
    }
    
    /// 测试：保存并加载草稿
    func testSaveAndLoadDraft() throws {
        // Given
        let entry = DiaryEntry(
            id: UUID(),
            mediaType: .photo,
            localMediaPath: "test/image.jpg",
            thumbnailPath: "test/thumb.jpg"
        )
        
        // When
        try draftManager.saveDraft(entry)
        let loadedEntry = try draftManager.loadDraft(id: entry.id)
        
        // Then
        XCTAssertEqual(loadedEntry.id, entry.id, "ID 应一致")
        XCTAssertEqual(loadedEntry.mediaType, entry.mediaType, "媒体类型应一致")
        XCTAssertEqual(loadedEntry.localMediaPath, entry.localMediaPath, "本机路径应一致")
        XCTAssertEqual(loadedEntry.thumbnailPath, entry.thumbnailPath, "缩略图路径应一致")
    }
    
    /// 测试：加载不存在的草稿应抛出错误
    func testLoadDraft_NotFound() {
        // Given
        let nonExistentId = UUID()
        
        // When/Then
        XCTAssertThrowsError(try draftManager.loadDraft(id: nonExistentId)) { error in
            guard let draftError = error as? DraftManagerError else {
                XCTFail("应为 DraftManagerError 类型")
                return
            }
            XCTAssertEqual(draftError, .draftNotFound, "应为 draftNotFound 错误")
        }
    }
    
    /// 测试：加载所有草稿
    func testLoadAllDrafts() throws {
        // Given
        let entry1 = DiaryEntry(mediaType: .photo)
        let entry2 = DiaryEntry(mediaType: .video)
        let entry3 = DiaryEntry(mediaType: .photo)
        
        try draftManager.saveDraft(entry1)
        try draftManager.saveDraft(entry2)
        try draftManager.saveDraft(entry3)
        
        // When
        let allDrafts = draftManager.loadAllDrafts()
        
        // Then
        XCTAssertEqual(allDrafts.count, 3, "应有 3 个草稿")
    }
    
    /// 测试：删除草稿
    func testDeleteDraft() throws {
        // Given
        let entry = DiaryEntry(mediaType: .photo)
        try draftManager.saveDraft(entry)
        XCTAssertTrue(draftManager.hasDrafts())
        
        // When
        try draftManager.deleteDraft(id: entry.id)
        
        // Then
        XCTAssertFalse(draftManager.hasDrafts(), "删除后不应有草稿")
    }
    
    /// 测试：获取最近草稿
    func testGetMostRecentDraft() throws {
        // Given
        let entry1 = DiaryEntry(mediaType: .photo)
        try draftManager.saveDraft(entry1)
        
        // 稍等一下确保时间不同
        Thread.sleep(forTimeInterval: 0.1)
        
        var entry2 = DiaryEntry(mediaType: .video)
        entry2.touch() // 更新时间
        try draftManager.saveDraft(entry2)
        
        // When
        let mostRecent = draftManager.getMostRecentDraft()
        
        // Then
        XCTAssertNotNil(mostRecent, "应有最近草稿")
        XCTAssertEqual(mostRecent?.id, entry2.id, "最近草稿应为 entry2")
    }
    
    /// 测试：草稿包含聊天消息
    func testDraftWithMessages() throws {
        // Given
        var entry = DiaryEntry(mediaType: .photo)
        entry.messages = [
            ChatMessage(sender: .user, content: "Hello"),
            ChatMessage(sender: .ai, content: "Hi there!")
        ]
        
        // When
        try draftManager.saveDraft(entry)
        let loadedEntry = try draftManager.loadDraft(id: entry.id)
        
        // Then
        XCTAssertEqual(loadedEntry.messages.count, 2, "应有 2 条消息")
        XCTAssertEqual(loadedEntry.messages[0].sender, .user)
        XCTAssertEqual(loadedEntry.messages[0].content, "Hello")
        XCTAssertEqual(loadedEntry.messages[1].sender, .ai)
    }
    
    /// 测试：草稿包含用户输入文字
    func testDraftWithUserInput() throws {
        // Given
        var entry = DiaryEntry(mediaType: .photo)
        entry.userInputText = "今天是美好的一天"
        
        // When
        try draftManager.saveDraft(entry)
        let loadedEntry = try draftManager.loadDraft(id: entry.id)
        
        // Then
        XCTAssertEqual(loadedEntry.userInputText, "今天是美好的一天")
    }
}

// MARK: - DiaryEntry 模型测试

final class DiaryEntryTests: XCTestCase {
    
    /// 测试：默认初始化值
    func testDefaultInitialization() {
        // When
        let entry = DiaryEntry(mediaType: .photo)
        
        // Then
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.mediaType, .photo)
        XCTAssertNil(entry.localMediaPath)
        XCTAssertNil(entry.cloudMediaPath)
        XCTAssertNil(entry.thumbnailPath)
        XCTAssertNil(entry.userInputText)
        XCTAssertTrue(entry.messages.isEmpty)
        XCTAssertNil(entry.aiAnalysisResult)
        XCTAssertNil(entry.diarySummary)
        XCTAssertTrue(entry.tagIds.isEmpty)
        XCTAssertFalse(entry.isAnalyzed)
        XCTAssertFalse(entry.isSummarized)
        XCTAssertFalse(entry.isSaved)
        XCTAssertEqual(entry.syncStatus, .local)
        XCTAssertNil(entry.lastErrorMessage)
    }
    
    /// 测试：带路径初始化
    func testInitializationWithPaths() {
        // Given
        let localPath = "DiaryMedia/test.jpg"
        let thumbnailPath = "Thumbnails/test_thumb.jpg"
        
        // When
        let entry = DiaryEntry(
            mediaType: .video,
            localMediaPath: localPath,
            thumbnailPath: thumbnailPath
        )
        
        // Then
        XCTAssertEqual(entry.mediaType, .video)
        XCTAssertEqual(entry.localMediaPath, localPath)
        XCTAssertEqual(entry.thumbnailPath, thumbnailPath)
    }
    
    /// 测试：isDraft 计算属性
    func testIsDraft() {
        // Given
        var entry = DiaryEntry(mediaType: .photo)
        
        // Then - 初始为草稿
        XCTAssertTrue(entry.isDraft)
        
        // When - 标记为已保存
        entry.isSaved = true
        
        // Then - 不再是草稿
        XCTAssertFalse(entry.isDraft)
    }
    
    /// 测试：hasMedia 计算属性
    func testHasMedia() {
        // Given
        var entry = DiaryEntry(mediaType: .photo)
        
        // Then - 初始无媒体
        XCTAssertFalse(entry.hasMedia)
        
        // When - 设置本机路径
        entry.localMediaPath = "test/path.jpg"
        
        // Then - 有媒体
        XCTAssertTrue(entry.hasMedia)
    }
    
    /// 测试：displaySummary 计算属性
    func testDisplaySummary() {
        // Given
        var entry = DiaryEntry(mediaType: .photo)
        
        // Then - 初始为 nil
        XCTAssertNil(entry.displaySummary)
        
        // When - 设置用户输入
        entry.userInputText = "用户输入"
        
        // Then - 显示用户输入
        XCTAssertEqual(entry.displaySummary, "用户输入")
        
        // When - 设置 AI 总结
        entry.diarySummary = "AI 总结"
        
        // Then - 优先显示 AI 总结
        XCTAssertEqual(entry.displaySummary, "AI 总结")
    }
    
    /// 测试：touch() 更新时间
    func testTouch() {
        // Given
        var entry = DiaryEntry(mediaType: .photo)
        let originalUpdatedAt = entry.updatedAt
        
        // 等待一小段时间
        Thread.sleep(forTimeInterval: 0.1)
        
        // When
        entry.touch()
        
        // Then
        XCTAssertGreaterThan(entry.updatedAt, originalUpdatedAt, "更新时间应增加")
    }
    
    /// 测试：Codable 编解码
    func testCodable() throws {
        // Given
        var entry = DiaryEntry(
            mediaType: .photo,
            localMediaPath: "test/path.jpg",
            thumbnailPath: "test/thumb.jpg"
        )
        entry.userInputText = "测试文字"
        entry.messages = [
            ChatMessage(sender: .user, content: "Hello"),
            ChatMessage(sender: .ai, content: "World")
        ]
        entry.tagIds = [UUID(), UUID()]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // When
        let data = try encoder.encode(entry)
        let decoded = try decoder.decode(DiaryEntry.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.mediaType, entry.mediaType)
        XCTAssertEqual(decoded.localMediaPath, entry.localMediaPath)
        XCTAssertEqual(decoded.userInputText, entry.userInputText)
        XCTAssertEqual(decoded.messages.count, entry.messages.count)
        XCTAssertEqual(decoded.tagIds.count, entry.tagIds.count)
    }
}

// MARK: - ChatMessage 模型测试

final class ChatMessageTests: XCTestCase {
    
    /// 测试：用户消息创建
    func testUserMessage() {
        // When
        let message = ChatMessage(sender: .user, content: "Hello")
        
        // Then
        XCTAssertEqual(message.sender, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }
    
    /// 测试：AI 消息创建
    func testAIMessage() {
        // When
        let message = ChatMessage(sender: .ai, content: "Hi there!")
        
        // Then
        XCTAssertEqual(message.sender, .ai)
        XCTAssertEqual(message.content, "Hi there!")
    }
    
    /// 测试：Codable 编解码
    func testCodable() throws {
        // Given
        let message = ChatMessage(sender: .user, content: "Test message")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // When
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ChatMessage.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.id, message.id)
        XCTAssertEqual(decoded.sender, message.sender)
        XCTAssertEqual(decoded.content, message.content)
    }
}

// MARK: - MediaType & SyncStatus 测试

final class EnumTests: XCTestCase {
    
    /// 测试：MediaType 编解码
    func testMediaTypeCodable() throws {
        // Given
        let photo = MediaType.photo
        let video = MediaType.video
        
        // When
        let photoData = try JSONEncoder().encode(photo)
        let videoData = try JSONEncoder().encode(video)
        
        let decodedPhoto = try JSONDecoder().decode(MediaType.self, from: photoData)
        let decodedVideo = try JSONDecoder().decode(MediaType.self, from: videoData)
        
        // Then
        XCTAssertEqual(decodedPhoto, .photo)
        XCTAssertEqual(decodedVideo, .video)
    }
    
    /// 测试：SyncStatus 编解码
    func testSyncStatusCodable() throws {
        // Given
        let statuses: [SyncStatus] = [.local, .syncing, .synced, .failed]
        
        for status in statuses {
            // When
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(SyncStatus.self, from: data)
            
            // Then
            XCTAssertEqual(decoded, status)
        }
    }
}

// MARK: - 错误处理测试

final class ErrorHandlingTests: XCTestCase {
    
    /// 测试：MediaManagerError 错误描述
    func testMediaManagerErrorDescriptions() {
        XCTAssertNotNil(MediaManagerError.failedToCreateDirectory.errorDescription)
        XCTAssertNotNil(MediaManagerError.failedToSaveMedia.errorDescription)
        XCTAssertNotNil(MediaManagerError.failedToGenerateThumbnail.errorDescription)
        XCTAssertNotNil(MediaManagerError.invalidMediaData.errorDescription)
        XCTAssertNotNil(MediaManagerError.videoTooLarge(maxSizeMB: 100).errorDescription)
        XCTAssertNotNil(MediaManagerError.unsupportedMediaType.errorDescription)
        
        // 检查视频过大错误包含大小限制
        let videoError = MediaManagerError.videoTooLarge(maxSizeMB: 100)
        XCTAssertTrue(videoError.errorDescription?.contains("100") ?? false)
    }
    
    /// 测试：DraftManagerError 错误描述
    func testDraftManagerErrorDescriptions() {
        XCTAssertNotNil(DraftManagerError.failedToSave.errorDescription)
        XCTAssertNotNil(DraftManagerError.failedToLoad.errorDescription)
        XCTAssertNotNil(DraftManagerError.failedToDelete.errorDescription)
        XCTAssertNotNil(DraftManagerError.draftNotFound.errorDescription)
    }
    
    /// 测试：DraftManagerError Equatable
    func testDraftManagerErrorEquatable() {
        XCTAssertEqual(DraftManagerError.failedToSave, DraftManagerError.failedToSave)
        XCTAssertEqual(DraftManagerError.draftNotFound, DraftManagerError.draftNotFound)
        XCTAssertNotEqual(DraftManagerError.failedToSave, DraftManagerError.failedToLoad)
    }
}
