//
//  Tag.swift
//  innerBloom
//
//  标签数据模型 - D-008
//

import Foundation

/// 标签模型，用于日记分类
/// 对应 D-008：标签清单
struct Tag: Identifiable, Hashable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var color: String? // 可选：标签颜色
    var icon: String?  // 可选：标签图示
    var isSystemDefault: Bool // 是否系统预设标签
    
    // MARK: - 初始化
    
    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        color: String? = nil,
        icon: String? = nil,
        isSystemDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.color = color
        self.icon = icon
        self.isSystemDefault = isSystemDefault
        
        // Debug: 标签创建日志
        print("[Tag] Created tag: \(name), isDefault: \(isSystemDefault)")
    }
}

// MARK: - 预设标签

extension Tag {
    /// 「全部」标签 - 系统预设，始终显示
    static let all = Tag(
        name: "全部",
        sortOrder: -1,
        icon: "square.grid.2x2",
        isSystemDefault: true
    )
    
    /// 示例标签（用于 Preview）
    static let samples: [Tag] = [
        .all,
        Tag(name: "旅行", sortOrder: 0, icon: "airplane"),
        Tag(name: "朋友", sortOrder: 1, icon: "person.2"),
        Tag(name: "开心", sortOrder: 2, icon: "face.smiling"),
        Tag(name: "焦虑", sortOrder: 3, icon: "cloud.rain"),
        Tag(name: "工作", sortOrder: 4, icon: "briefcase")
    ]
}
