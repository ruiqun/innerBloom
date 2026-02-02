//
//  EnvironmentService.swift
//  innerBloom
//
//  环境服务 - B-010, F-016
//  App 启动时自动触发天气刷新
//  统一管理位置和天气信息
//

import Foundation
import CoreLocation
import Combine

/// 环境状态
enum EnvironmentStatus {
    case idle
    case requestingPermission
    case locating
    case fetchingWeather
    case ready
    case failed(String)
    case denied
}

/// 环境服务
@Observable
final class EnvironmentService {
    
    // MARK: - Singleton
    
    static let shared = EnvironmentService()
    
    // MARK: - Dependencies
    
    private let locationManager = LocationManager.shared
    private let weatherService = WeatherService.shared
    
    // MARK: - State
    
    /// 当前状态
    private(set) var status: EnvironmentStatus = .idle
    
    /// 当前位置
    private(set) var currentLocation: LocationResult?
    
    /// 当前天气
    private(set) var currentWeather: WeatherData?
    
    /// 是否在中国
    private(set) var isInChina: Bool = false
    
    /// 最后更新时间
    private(set) var lastUpdated: Date?
    
    /// 错误信息
    private(set) var errorMessage: String?
    
    /// 最后一次触发刷新的时间（用于防抖）
    private var lastRefreshTrigger: Date?
    
    /// 防抖间隔（秒）
    private let debounceInterval: TimeInterval = 2.0
    
    // MARK: - Computed
    
    /// 是否有有效数据
    var hasValidData: Bool {
        currentWeather != nil
    }
    
    /// 是否被用户拒绝定位
    var isLocationDenied: Bool {
        locationManager.isDenied
    }
    
    /// 环境上下文（用于 AI）
    var environmentContext: EnvironmentContext? {
        guard let weather = currentWeather else { return nil }
        
        var locationInfo: LocationInfo?
        if let loc = currentLocation {
            locationInfo = LocationInfo(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                city: nil
            )
        }
        
        let weatherInfo = WeatherInfo(
            condition: weather.conditionText,
            iconCode: weather.conditionIcon,
            temperature: weather.currentTempC,
            feelsLike: nil,
            humidity: nil
        )
        
        return EnvironmentContext(location: locationInfo, weather: weatherInfo)
    }
    
    // MARK: - Initialization
    
    private init() {
        print("[EnvironmentService] Initialized")
    }
    
    // MARK: - Public Methods
    
    /// App 进入前台时调用（自动刷新）
    func onAppBecomeActive() {
        // 防抖：2秒内不重复触发
        if let lastTrigger = lastRefreshTrigger,
           Date().timeIntervalSince(lastTrigger) < debounceInterval {
            print("[EnvironmentService] ⏭️ Debounced (triggered \(String(format: "%.1f", Date().timeIntervalSince(lastTrigger)))s ago)")
            return
        }
        
        lastRefreshTrigger = Date()
        print("[EnvironmentService] 🚀 App became active")
        
        Task { @MainActor in
            await refreshIfNeeded()
        }
    }
    
    /// 刷新环境数据（如果需要）
    @MainActor
    func refreshIfNeeded() async {
        // 30 分钟内不重复刷新
        if let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < 30 * 60,
           currentWeather != nil {
            print("[EnvironmentService] ⏭️ Skip refresh (last: \(Int(Date().timeIntervalSince(lastUpdated)))s ago)")
            return
        }
        
        await refresh(forceRefresh: false)
    }
    
    /// 强制刷新环境数据
    @MainActor
    func refresh(forceRefresh: Bool = true) async {
        print("[EnvironmentService] 🔄 Starting refresh (force: \(forceRefresh))")
        
        // 检查定位权限
        if locationManager.isDenied {
            status = .denied
            errorMessage = "位置权限被拒绝，无法获取天气"
            print("[EnvironmentService] ❌ Location denied")
            printCurrentState()
            return
        }
        
        // 如果未授权，请求权限
        if !locationManager.isAuthorized {
            status = .requestingPermission
            print("[EnvironmentService] 🔐 Requesting location permission...")
            locationManager.requestAuthorization()
            
            // 等待用户响应
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            if locationManager.isDenied {
                status = .denied
                errorMessage = "位置权限被拒绝"
                print("[EnvironmentService] ❌ Permission denied by user")
                printCurrentState()
                return
            }
            
            if !locationManager.isAuthorized {
                status = .failed("等待授权")
                errorMessage = "请在设置中允许位置访问"
                print("[EnvironmentService] ⚠️ Still waiting for authorization")
                printCurrentState()
                return
            }
        }
        
        // 获取位置
        status = .locating
        errorMessage = nil
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 获取位置和国家代码
            let location = try await locationManager.getLocationWithCountry()
            currentLocation = location
            isInChina = location.isInChina
            
            let locationTime = CFAbsoluteTimeGetCurrent() - startTime
            print("[EnvironmentService] 📍 Location ready in \(String(format: "%.2f", locationTime))s")
            
            // 获取天气
            status = .fetchingWeather
            
            let weatherStartTime = CFAbsoluteTimeGetCurrent()
            let weather = try await weatherService.getWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                isChina: location.isInChina,
                forceRefresh: forceRefresh
            )
            
            currentWeather = weather
            lastUpdated = Date()
            status = .ready
            
            let weatherTime = CFAbsoluteTimeGetCurrent() - weatherStartTime
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            
            print("[EnvironmentService] 🌤️ Weather ready in \(String(format: "%.2f", weatherTime))s")
            print("[EnvironmentService] ✅ Total refresh time: \(String(format: "%.2f", totalTime))s")
            
            printCurrentState()
            
        } catch let error as LocationError {
            handleLocationError(error)
        } catch {
            status = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            print("[EnvironmentService] ❌ Refresh failed: \(error)")
            printCurrentState()
        }
    }
    
    /// 请求位置权限
    func requestLocationPermission() {
        locationManager.requestAuthorization()
    }
    
    /// 获取时间上下文（立即可用，不需要网络）
    func getTimeContext() -> EnvironmentContext {
        EnvironmentContext(location: nil, weather: nil)
    }
    
    // MARK: - Private Methods
    
    private func handleLocationError(_ error: LocationError) {
        switch error {
        case .timeout:
            // 定位超时，不使用定位/天气
            status = .failed("定位超时")
            errorMessage = "定位超时，无法获取天气"
            print("[EnvironmentService] ⏰ Location timeout - weather will not be used for AI")
            
        case .denied:
            status = .denied
            errorMessage = "位置权限被拒绝"
            print("[EnvironmentService] ❌ Location denied")
            
        default:
            status = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            print("[EnvironmentService] ❌ Location error: \(error)")
        }
        printCurrentState()
    }
    
    // MARK: - Debug
    
    private func printCurrentState() {
        print("[EnvironmentService] ═══════════════════════════════════════")
        print("[EnvironmentService] 📊 当前环境状态")
        print("[EnvironmentService] ───────────────────────────────────────")
        print("[EnvironmentService]   状态: \(status)")
        
        if let loc = currentLocation {
            print("[EnvironmentService]   位置: (\(String(format: "%.4f", loc.coordinate.latitude)), \(String(format: "%.4f", loc.coordinate.longitude)))")
            print("[EnvironmentService]   精度: \(String(format: "%.1f", loc.accuracy))m")
            print("[EnvironmentService]   国家: \(loc.isoCountryCode ?? "未知") (\(isInChina ? "中国" : "海外"))")
        } else {
            print("[EnvironmentService]   位置: 无")
        }
        
        if let weather = currentWeather {
            print("[EnvironmentService]   天气: \(weather.conditionText), \(weather.temperatureText)")
            print("[EnvironmentService]   下雨: \(weather.isRainingNow ? "是" : "否")")
            if let prob = weather.nextHourRainProbability {
                print("[EnvironmentService]   1小时降雨概率: \(prob)%")
            }
            if let precip = weather.nextHourPrecipMM {
                print("[EnvironmentService]   1小时降水量: \(precip)mm")
            }
            print("[EnvironmentService]   来源: \(weather.source.rawValue)")
        } else {
            print("[EnvironmentService]   天气: 无")
        }
        
        if let updated = lastUpdated {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone.current
            print("[EnvironmentService]   更新时间: \(formatter.string(from: updated))")
        }
        
        if let error = errorMessage {
            print("[EnvironmentService]   错误: \(error)")
        }
        
        print("[EnvironmentService] ═══════════════════════════════════════")
    }
}

// MARK: - 辅助方法

extension EnvironmentStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle: return "空闲"
        case .requestingPermission: return "请求权限中"
        case .locating: return "定位中"
        case .fetchingWeather: return "获取天气中"
        case .ready: return "就绪"
        case .failed(let msg): return "失败: \(msg)"
        case .denied: return "权限被拒绝"
        }
    }
}
