//
//  WeatherData.swift
//  innerBloom
//
//  天气数据模型 - B-010, F-016
//  精简的天气数据，只包含必要信息
//

import Foundation

/// 天气数据（精简版）
struct WeatherData: Codable {
    /// 当前温度（摄氏度）
    let currentTempC: Double
    
    /// 天气描述（如：多云、小雨）
    let conditionText: String
    
    /// 天气图标代码
    let conditionIcon: String?
    
    /// 现在是否下雨
    let isRainingNow: Bool
    
    /// 下一小时降雨概率（0-100，可能为 nil）
    let nextHourRainProbability: Int?
    
    /// 下一小时降水量（mm，可能为 nil）
    let nextHourPrecipMM: Double?
    
    /// 数据更新时间
    let updatedAt: Date
    
    /// 数据来源
    let source: WeatherSource
    
    /// 坐标（用于缓存校验）
    let latitude: Double
    let longitude: Double
    
    // MARK: - Computed
    
    /// 温度显示文字
    var temperatureText: String {
        "\(Int(round(currentTempC)))°C"
    }
    
    /// 完整天气描述
    var fullDescription: String {
        var desc = "\(conditionText)，\(temperatureText)"
        if isRainingNow {
            desc += "，正在下雨"
        }
        if let prob = nextHourRainProbability, prob > 0 {
            desc += "，未来1小时降雨概率\(prob)%"
        }
        return desc
    }
    
    /// 用于 AI 的简短描述
    var aiDescription: String {
        var parts: [String] = []
        parts.append("\(conditionText)")
        parts.append("气温\(temperatureText)")
        
        if isRainingNow {
            parts.append("正在下雨")
        } else if let prob = nextHourRainProbability, prob >= 50 {
            parts.append("可能下雨")
        }
        
        return parts.joined(separator: "，")
    }
}

/// 天气数据来源
enum WeatherSource: String, Codable {
    case weatherKit = "WeatherKit"
    case qWeather = "QWeather"
    case mock = "Mock"
}

/// 天气缓存
struct WeatherCache: Codable {
    let data: WeatherData
    let cachedAt: Date
    
    /// 缓存是否有效（30分钟内）
    var isValid: Bool {
        Date().timeIntervalSince(cachedAt) < 30 * 60
    }
    
    /// 缓存是否匹配位置（1km 内）
    func matchesLocation(latitude: Double, longitude: Double) -> Bool {
        let latDiff = abs(data.latitude - latitude)
        let lonDiff = abs(data.longitude - longitude)
        // 约 1km 范围
        return latDiff < 0.01 && lonDiff < 0.01
    }
}

// MARK: - 用于 API 响应解析

/// Edge Function 天气响应
struct WeatherAPIResponse: Codable {
    let currentTempC: Double
    let conditionText: String
    let conditionIcon: String?
    let isRainingNow: Bool
    let nextHourRainProbability: Int?
    let nextHourPrecipMM: Double?
    let source: String
    
    func toWeatherData(latitude: Double, longitude: Double) -> WeatherData {
        WeatherData(
            currentTempC: currentTempC,
            conditionText: conditionText,
            conditionIcon: conditionIcon,
            isRainingNow: isRainingNow,
            nextHourRainProbability: nextHourRainProbability,
            nextHourPrecipMM: nextHourPrecipMM,
            updatedAt: Date(),
            source: WeatherSource(rawValue: source) ?? .mock,
            latitude: latitude,
            longitude: longitude
        )
    }
}
