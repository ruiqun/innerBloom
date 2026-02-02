//
//  LocalDraftManager.swift
//  innerBloom
//
//  本机草稿管理器 - B-003
//  负责：日记草稿持久化存储、离线保存、草稿恢复
//

import Foundation

/// 草稿管理错误
enum DraftManagerError: LocalizedError, Equatable {
    case failedToSave
    case failedToLoad
    case failedToDelete
    case draftNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedToSave:
            return "草稿保存失败"
        case .failedToLoad:
            return "草稿加载失败"
        case .failedToDelete:
            return "草稿删除失败"
        case .draftNotFound:
            return "草稿不存在"
        }
    }
}

/// 本机草稿管理器
/// 单例模式，负责日记草稿的本机持久化
final class LocalDraftManager {
    
    // MARK: - Singleton
    
    static let shared = LocalDraftManager()
    
    // MARK: - Constants
    
    /// 草稿存储目录名称
    private let draftDirectoryName = "Drafts"
    /// 草稿列表文件名
    private let draftListFileName = "drafts_index.json"
    
    // MARK: - Computed Properties
    
    /// Documents 目录 URL
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// 草稿目录 URL
    private var draftDirectoryURL: URL {
        documentsURL.appendingPathComponent(draftDirectoryName)
    }
    
    /// 草稿索引文件 URL
    private var draftIndexURL: URL {
        draftDirectoryURL.appendingPathComponent(draftListFileName)
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDirectory()
    }
    
    /// 创建草稿存储目录
    private func setupDirectory() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: draftDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: draftDirectoryURL, withIntermediateDirectories: true)
                print("[LocalDraftManager] Created draft directory: \(draftDirectoryURL.path)")
            } catch {
                print("[LocalDraftManager] Error creating directory: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 保存草稿
    /// - Parameter entry: 日记条目
    func saveDraft(_ entry: DiaryEntry) throws {
        print("[LocalDraftManager] Saving draft: \(entry.id)")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // 1. 将 DiaryEntry 编码为 JSON
        let data: Data
        do {
            data = try encoder.encode(entry)
        } catch {
            print("[LocalDraftManager] Encode error: \(error)")
            throw DraftManagerError.failedToSave
        }
        
        // 2. 保存到单独的文件
        let fileURL = draftDirectoryURL.appendingPathComponent("\(entry.id.uuidString).json")
        do {
            try data.write(to: fileURL)
            print("[LocalDraftManager] Draft saved: \(fileURL.path)")
        } catch {
            print("[LocalDraftManager] Write error: \(error)")
            throw DraftManagerError.failedToSave
        }
        
        // 3. 更新草稿索引
        try updateDraftIndex(adding: entry.id)
    }
    
    /// 加载指定草稿
    /// - Parameter id: 日记 ID
    /// - Returns: 日记条目
    func loadDraft(id: UUID) throws -> DiaryEntry {
        print("[LocalDraftManager] Loading draft: \(id)")
        
        let fileURL = draftDirectoryURL.appendingPathComponent("\(id.uuidString).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DraftManagerError.draftNotFound
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try decoder.decode(DiaryEntry.self, from: data)
            print("[LocalDraftManager] Draft loaded: \(id)")
            return entry
        } catch {
            print("[LocalDraftManager] Decode error: \(error)")
            throw DraftManagerError.failedToLoad
        }
    }
    
    /// 加载所有草稿
    /// - Returns: 草稿列表
    func loadAllDrafts() -> [DiaryEntry] {
        print("[LocalDraftManager] Loading all drafts...")
        
        let draftIds = getDraftIds()
        var drafts: [DiaryEntry] = []
        
        for id in draftIds {
            if let entry = try? loadDraft(id: id) {
                drafts.append(entry)
            }
        }
        
        // 按更新时间倒序排列
        drafts.sort { $0.updatedAt > $1.updatedAt }
        
        print("[LocalDraftManager] Loaded \(drafts.count) drafts")
        return drafts
    }
    
    /// 删除草稿
    /// - Parameter id: 日记 ID
    func deleteDraft(id: UUID) throws {
        print("[LocalDraftManager] Deleting draft: \(id)")
        
        let fileURL = draftDirectoryURL.appendingPathComponent("\(id.uuidString).json")
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            try updateDraftIndex(removing: id)
            print("[LocalDraftManager] Draft deleted: \(id)")
        } catch {
            print("[LocalDraftManager] Delete error: \(error)")
            throw DraftManagerError.failedToDelete
        }
    }
    
    /// 检查是否有未保存的草稿
    /// - Returns: 是否存在草稿
    func hasDrafts() -> Bool {
        !getDraftIds().isEmpty
    }
    
    /// 获取最近的草稿
    /// - Returns: 最近更新的草稿或 nil
    func getMostRecentDraft() -> DiaryEntry? {
        loadAllDrafts().first
    }
    
    /// 清理所有草稿（用于开发/调试）
    func clearAllDrafts() {
        let draftIds = getDraftIds()
        for id in draftIds {
            try? deleteDraft(id: id)
        }
        print("[LocalDraftManager] All drafts cleared")
    }
    
    // MARK: - Private Methods
    
    /// 获取草稿 ID 列表
    private func getDraftIds() -> [UUID] {
        guard FileManager.default.fileExists(atPath: draftIndexURL.path),
              let data = try? Data(contentsOf: draftIndexURL),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return ids
    }
    
    /// 更新草稿索引（添加）
    private func updateDraftIndex(adding id: UUID) throws {
        var ids = getDraftIds()
        if !ids.contains(id) {
            ids.append(id)
        }
        try saveDraftIndex(ids)
    }
    
    /// 更新草稿索引（移除）
    private func updateDraftIndex(removing id: UUID) throws {
        var ids = getDraftIds()
        ids.removeAll { $0 == id }
        try saveDraftIndex(ids)
    }
    
    /// 保存草稿索引
    private func saveDraftIndex(_ ids: [UUID]) throws {
        let data = try JSONEncoder().encode(ids)
        try data.write(to: draftIndexURL)
    }
}
