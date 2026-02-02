//
//  WeatherService.swift
//  innerBloom
//
//  天气服务 - B-010, F-016
//  自动选择供应商：中国 → QWeather，海外 → WeatherKit
//  通过 Supabase Edge Function 代理调用
//

import Foundation
import CoreLocation

/// 天气服务错误
enum WeatherServiceError: LocalizedError {
    case noLocation
    case networkError(String)
    case apiError(String)
    case timeout
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noLocation:
            return "无法获取位置信息"
        case .networkError(let message):
            return "网络错误：\(message)"
        case .apiError(let message):
            return "天气服务错误：\(message)"
        case .timeout:
            return "请求超时"
        case .invalidResponse:
            return "天气数据解析失败"
        }
    }
}

/// 天气服务
@Observable
final class WeatherService {
    
    // MARK: - Singleton
    
    static let shared = WeatherService()
    
    // MARK: - State
    
    /// 当前天气数据
    private(set) var currentWeather: WeatherData?
    
    /// 是否正在加载
    private(set) var isLoading: Bool = false
    
    /// 最后错误
    private(set) var lastError: String?
    
    // MARK: - Cache
    
    private let cacheKey = "innerBloom_weather_cache"
    private var cachedWeather: WeatherCache?
    
    /// 缓存有效期（秒）
    private let cacheTimeout: TimeInterval = 30 * 60 // 30 分钟
    
    // MARK: - Configuration
    
    private let session: URLSession
    private let requestTimeout: TimeInterval = 10.0
    
    /// Edge Function URL
    private var edgeFunctionURL: URL? {
        let projectURL = SupabaseConfig.shared.projectURL
        guard !projectURL.isEmpty else { return nil }
        return URL(string: "\(projectURL)/functions/v1/weather")
    }
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        self.session = URLSession(configuration: config)
        
        // 加载缓存
        loadCache()
        print("[WeatherService] Initialized, cached: \(cachedWeather != nil)")
    }
    
    // MARK: - Public Methods
    
    /// 获取天气数据
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - isChina: 是否在中国（用于选择供应商）
    ///   - forceRefresh: 是否强制刷新（忽略缓存）
    /// - Returns: 天气数据
    func getWeather(
        latitude: Double,
        longitude: Double,
        isChina: Bool,
        forceRefresh: Bool = false
    ) async throws -> WeatherData {
        print("[WeatherService] 🌤️ Getting weather: (\(latitude), \(longitude)), isChina: \(isChina), force: \(forceRefresh)")
        
        // 检查缓存
        if !forceRefresh,
           let cache = cachedWeather,
           cache.isValid,
           cache.matchesLocation(latitude: latitude, longitude: longitude) {
            print("[WeatherService] ✅ Using cached weather (age: \(Int(Date().timeIntervalSince(cache.cachedAt)))s)")
            currentWeather = cache.data
            return cache.data
        }
        
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        // 调用 Edge Function
        let weather = try await fetchWeatherFromEdgeFunction(
            latitude: latitude,
            longitude: longitude,
            isChina: isChina
        )
        
        // 更新状态和缓存
        currentWeather = weather
        saveCache(weather)
        
        // 打印完整天气数据
        printWeatherDetails(weather)
        
        return weather
    }
    
    /// 获取天气（自动获取位置和国家）
    func getWeatherAutomatic() async throws -> WeatherData {
        let locationManager = LocationManager.shared
        
        // 获取位置和国家
        let locationResult = try await locationManager.getLocationWithCountry()
        
        return try await getWeather(
            latitude: locationResult.coordinate.latitude,
            longitude: locationResult.coordinate.longitude,
            isChina: locationResult.isInChina
        )
    }
    
    /// 清除缓存
    func clearCache() {
        cachedWeather = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
        print("[WeatherService] Cache cleared")
    }
    
    // MARK: - Private Methods
    
    /// 从 Edge Function 获取天气
    private func fetchWeatherFromEdgeFunction(
        latitude: Double,
        longitude: Double,
        isChina: Bool
    ) async throws -> WeatherData {
        guard let url = edgeFunctionURL else {
            print("[WeatherService] ⚠️ Edge Function not configured, using mock")
            return mockWeather(latitude: latitude, longitude: longitude)
        }
        
        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.shared.anonKey)", forHTTPHeaderField: "Authorization")
        
        struct WeatherRequest: Codable {
            let latitude: Double
            let longitude: Double
            let provider: String // "qweather" or "weatherkit"
        }
        
        let requestBody = WeatherRequest(
            latitude: latitude,
            longitude: longitude,
            provider: isChina ? "qweather" : "weatherkit"
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("[WeatherService] 🌐 Calling Edge Function, provider: \(requestBody.provider)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[WeatherService] ❌ API error: \(httpResponse.statusCode) - \(errorMsg)")
                throw WeatherServiceError.apiError("状态码: \(httpResponse.statusCode)")
            }
            
            let apiResponse = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
            let weather = apiResponse.toWeatherData(latitude: latitude, longitude: longitude)
            
            print("[WeatherService] ✅ Weather received from \(weather.source.rawValue)")
            return weather
            
        } catch let error as WeatherServiceError {
            throw error
        } catch {
            print("[WeatherService] ❌ Network error: \(error)")
            
            // 如果有缓存，返回过期缓存
            if let cache = cachedWeather {
                print("[WeatherService] ⚠️ Returning stale cache due to error")
                return cache.data
            }
            
            // 返回 mock 数据
            print("[WeatherService] ⚠️ Returning mock data due to error")
            return mockWeather(latitude: latitude, longitude: longitude)
        }
    }
    
    /// Mock 天气数据
    private func mockWeather(latitude: Double, longitude: Double) -> WeatherData {
        let hour = Calendar.current.component(.hour, from: Date())
        
        let temp: Double
        let condition: String
        let isRaining: Bool
        
        switch hour {
        case 6..<10:
            temp = 18
            condition = "晴朗"
            isRaining = false
        case 10..<14:
            temp = 24
            condition = "多云"
            isRaining = false
        case 14..<18:
            temp = 26
            condition = "晴朗"
            isRaining = false
        case 18..<22:
            temp = 22
            condition = "晴朗"
            isRaining = false
        default:
            temp = 16
            condition = "晴朗"
            isRaining = false
        }
        
        return WeatherData(
            currentTempC: temp,
            conditionText: condition,
            conditionIcon: nil,
            isRainingNow: isRaining,
            nextHourRainProbability: 10,
            nextHourPrecipMM: 0,
            updatedAt: Date(),
            source: .mock,
            latitude: latitude,
            longitude: longitude
        )
    }
    
    // MARK: - Cache Management
    
    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(WeatherCache.self, from: data) else {
            return
        }
        cachedWeather = cache
        currentWeather = cache.data
    }
    
    private func saveCache(_ weather: WeatherData) {
        let cache = WeatherCache(data: weather, cachedAt: Date())
        cachedWeather = cache
        
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    // MARK: - Debug
    
    private func printWeatherDetails(_ weather: WeatherData) {
        print("[WeatherService] ═══════════════════════════════════════")
        print("[WeatherService] 🌡️  天气数据详情")
        print("[WeatherService] ───────────────────────────────────────")
        print("[WeatherService]   当前温度: \(weather.temperatureText)")
        print("[WeatherService]   天气状况: \(weather.conditionText)")
        print("[WeatherService]   是否下雨: \(weather.isRainingNow ? "是" : "否")")
        if let prob = weather.nextHourRainProbability {
            print("[WeatherService]   1小时降雨概率: \(prob)%")
        }
        if let precip = weather.nextHourPrecipMM {
            print("[WeatherService]   1小时降水量: \(precip)mm")
        }
        print("[WeatherService]   数据来源: \(weather.source.rawValue)")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        print("[WeatherService]   更新时间: \(formatter.string(from: weather.updatedAt))")
        print("[WeatherService]   坐标: (\(weather.latitude), \(weather.longitude))")
        print("[WeatherService] ═══════════════════════════════════════")
    }
}
