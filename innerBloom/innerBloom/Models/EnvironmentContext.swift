//
//  EnvironmentContext.swift
//  innerBloom
//
//  环境上下文数据模型 - D-012, B-010
//  用于发送给 AI 作为 System Prompt 的一部分
//

import Foundation
import CoreLocation

/// 环境上下文（D-012）
/// 包含位置、天气、时间信息，用于增强 AI 对话体验
struct EnvironmentContext: Codable {
    /// 位置信息
    let location: LocationInfo?
    
    /// 天气信息
    let weather: WeatherInfo?
    
    /// 当地时间信息
    let timeInfo: TimeInfo
    
    /// 创建时间
    let capturedAt: Date
    
    init(location: LocationInfo? = nil, weather: WeatherInfo? = nil) {
        self.location = location
        self.weather = weather
        self.timeInfo = TimeInfo()
        self.capturedAt = Date()
    }
    
    /// 生成给 AI 的上下文描述
    var aiDescription: String {
        var parts: [String] = []
        
        // 时间描述
        parts.append("当前时间：\(timeInfo.description)")
        
        // 天气描述
        if let weather = weather {
            parts.append("天气状况：\(weather.description)")
        }
        
        // 位置描述（如果有城市名）
        if let location = location, let city = location.city {
            parts.append("所在地点：\(city)")
        }
        
        return parts.joined(separator: "；")
    }
    
    /// 是否有有效的环境信息
    var hasValidInfo: Bool {
        weather != nil || location != nil
    }
    
    /// 生成问候语
    func generateGreeting() -> String {
        var greeting = timeInfo.period.greeting
        
        // 加入天气信息
        if let weather = weather {
            greeting += "今天\(weather.shortDescription)。"
        }
        
        return greeting
    }
}

// MARK: - 位置信息

struct LocationInfo: Codable {
    /// 纬度
    let latitude: Double
    
    /// 经度
    let longitude: Double
    
    /// 城市名（可选，通过反向地理编码获得）
    var city: String?
    
    /// 区/县（可选）
    var district: String?
    
    /// 国家（可选）
    var country: String?
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    init(latitude: Double, longitude: Double, city: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
    }
}

// MARK: - 天气信息

struct WeatherInfo: Codable {
    /// 天气状况（如：晴、多云、小雨）
    let condition: String
    
    /// 天气图标代码（用于 UI 显示）
    let iconCode: String?
    
    /// 温度（摄氏度）
    let temperature: Double?
    
    /// 体感温度（摄氏度）
    let feelsLike: Double?
    
    /// 湿度（百分比）
    let humidity: Int?
    
    /// 天气描述（用于 AI）
    var description: String {
        var desc = condition
        
        if let temp = temperature {
            desc += "，气温 \(Int(temp))°C"
        }
        
        if let humidity = humidity {
            desc += "，湿度 \(humidity)%"
        }
        
        return desc
    }
    
    /// 简短描述（用于 AI 问候）
    var shortDescription: String {
        if let temp = temperature {
            return "\(condition)，\(Int(temp))°C"
        }
        return condition
    }
}

// MARK: - 时间信息

struct TimeInfo: Codable {
    /// 时段
    let period: TimePeriod
    
    /// 小时（24小时制）
    let hour: Int
    
    /// 是否是周末
    let isWeekend: Bool
    
    /// 星期几
    let weekday: Int
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .weekday], from: now)
        
        self.hour = components.hour ?? 12
        self.weekday = components.weekday ?? 1
        self.isWeekend = (weekday == 1 || weekday == 7)
        self.period = TimePeriod.from(hour: hour)
    }
    
    var description: String {
        let weekdayNames = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekdayName = weekdayNames[weekday]
        return "\(weekdayName)\(period.description)"
    }
}

/// 时段枚举
enum TimePeriod: String, Codable {
    case earlyMorning  // 凌晨 (0-5)
    case morning       // 早上 (6-11)
    case noon          // 中午 (11-13)
    case afternoon     // 下午 (13-17)
    case evening       // 傍晚 (17-19)
    case night         // 晚上 (19-23)
    
    static func from(hour: Int) -> TimePeriod {
        switch hour {
        case 0..<6:   return .earlyMorning
        case 6..<11:  return .morning
        case 11..<13: return .noon
        case 13..<17: return .afternoon
        case 17..<19: return .evening
        default:      return .night
        }
    }
    
    var description: String {
        switch self {
        case .earlyMorning: return "凌晨"
        case .morning:      return "早上"
        case .noon:         return "中午"
        case .afternoon:    return "下午"
        case .evening:      return "傍晚"
        case .night:        return "晚上"
        }
    }
    
    /// 时段对应的问候语（B-017: 跟随语言设定）
    var greeting: String {
        switch self {
        case .earlyMorning: return String.localized(.greetingEarlyMorning)
        case .morning:      return String.localized(.greetingMorning)
        case .noon:         return String.localized(.greetingNoon)
        case .afternoon:    return String.localized(.greetingAfternoon)
        case .evening:      return String.localized(.greetingEvening)
        case .night:        return String.localized(.greetingNight)
        }
    }
}
