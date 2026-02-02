//
//  AIChatResponse.swift
//  innerBloom
//
//  AI 聊天响应模型
//  支持结构化输出：主回复 + 追问 + 建议话题
//

import Foundation

/// AI 聊天响应（结构化）
struct AIChatResponse: Codable {
    /// 主回复内容
    let assistantReply: String
    
    /// 追问问题（最多2个，具体好回答的问题）
    let followUpQuestions: [String]?
    
    /// 建议话题/一键选项（最多3个，用户卡住时使用）
    let suggestedPrompts: [String]?
    
    /// 情绪标签
    let toneTags: [String]?
    
    /// 安全提示（如检测到负面情绪）
    let safetyNote: String?
    
    enum CodingKeys: String, CodingKey {
        case assistantReply = "assistant_reply"
        case followUpQuestions = "follow_up_questions"
        case suggestedPrompts = "suggested_prompts"
        case toneTags = "tone_tags"
        case safetyNote = "safety_note"
    }
    
    /// 从纯文本创建（兼容旧格式）
    static func fromPlainText(_ text: String) -> AIChatResponse {
        AIChatResponse(
            assistantReply: text,
            followUpQuestions: nil,
            suggestedPrompts: nil,
            toneTags: nil,
            safetyNote: nil
        )
    }
    
    /// 尝试从 JSON 解析，失败则当作纯文本
    static func parse(from text: String) -> AIChatResponse {
        // 尝试解析 JSON
        if let data = text.data(using: .utf8),
           let response = try? JSONDecoder().decode(AIChatResponse.self, from: data) {
            return response
        }
        
        // 尝试提取 JSON 部分（AI 可能返回带有其他文字的 JSON）
        if let jsonStart = text.firstIndex(of: "{"),
           let jsonEnd = text.lastIndex(of: "}") {
            let jsonString = String(text[jsonStart...jsonEnd])
            if let data = jsonString.data(using: .utf8),
               let response = try? JSONDecoder().decode(AIChatResponse.self, from: data) {
                return response
            }
        }
        
        // 降级为纯文本
        return fromPlainText(text)
    }
}

/// AI 聊天上下文（发送给 AI 的输入）
struct AIChatContext: Codable {
    /// 媒体分析结果（照片/影片内容描述）
    let mediaAnalysis: MediaAnalysisContext?
    
    /// 用户当前输入
    let userText: String?
    
    /// 最近对话历史
    let recentMessages: [MessageContext]?
    
    /// 本地时间信息
    let localTime: TimeContext?
    
    /// 天气信息
    let weather: WeatherContext?
    
    /// 输出语言
    let language: String?
    
    enum CodingKeys: String, CodingKey {
        case mediaAnalysis = "media_analysis"
        case userText = "user_text"
        case recentMessages = "recent_messages"
        case localTime = "local_time"
        case weather
        case language
    }
}

/// 媒体分析上下文
struct MediaAnalysisContext: Codable {
    let description: String
    let sceneTags: [String]?
    let mood: String?
    let hasPeople: Bool?
    
    enum CodingKeys: String, CodingKey {
        case description
        case sceneTags = "scene_tags"
        case mood
        case hasPeople = "has_people"
    }
}

/// 消息上下文
struct MessageContext: Codable {
    let role: String  // "user" or "assistant"
    let content: String
}

/// 时间上下文
struct TimeContext: Codable {
    let period: String      // "morning", "afternoon", "evening", "night"
    let hour: Int
    let weekday: String     // "周一", "周二", etc.
    let isWeekend: Bool
    
    enum CodingKeys: String, CodingKey {
        case period
        case hour
        case weekday
        case isWeekend = "is_weekend"
    }
}

/// 天气上下文
struct WeatherContext: Codable {
    let tempC: Double
    let conditionText: String
    let isRaining: Bool
    let nextHourPop: Int?       // 下一小时降雨概率
    let nextHourPrecip: Double? // 下一小时降水量
    
    enum CodingKeys: String, CodingKey {
        case tempC = "temp_c"
        case conditionText = "condition_text"
        case isRaining = "is_raining"
        case nextHourPop = "next_hour_pop"
        case nextHourPrecip = "next_hour_precip"
    }
}
