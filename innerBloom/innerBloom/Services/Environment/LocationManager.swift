//
//  LocationManager.swift
//  innerBloom
//
//  位置管理服务 - B-010, F-016
//  高精度定位 + 5秒超时 + 权限管理
//

import Foundation
import CoreLocation

/// 位置管理器错误
enum LocationError: LocalizedError {
    case notAuthorized
    case denied
    case unavailable
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "位置服务未授权"
        case .denied:
            return "位置服务被拒绝"
        case .unavailable:
            return "位置服务不可用"
        case .timeout:
            return "获取位置超时"
        case .unknown(let error):
            return "位置错误：\(error.localizedDescription)"
        }
    }
}

/// 位置结果
struct LocationResult {
    let coordinate: CLLocationCoordinate2D
    let accuracy: CLLocationAccuracy
    let timestamp: Date
    
    /// ISO 国家代码（反向地理编码后填充）
    var isoCountryCode: String?
    
    /// 是否在中国
    var isInChina: Bool {
        isoCountryCode == "CN"
    }
}

/// 位置管理器
@Observable
final class LocationManager: NSObject {
    
    // MARK: - Singleton
    
    static let shared = LocationManager()
    
    // MARK: - State
    
    /// 授权状态
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    /// 是否已授权
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    /// 是否被拒绝
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
    
    /// 是否正在获取位置
    private(set) var isLocating: Bool = false
    
    /// 最后一次位置结果
    private(set) var lastLocation: LocationResult?
    
    // MARK: - Configuration
    
    /// 定位超时时间（秒）
    private let locationTimeout: TimeInterval = 5.0
    
    // MARK: - Private
    
    private let locationManager = CLLocationManager()
    // private let geocoder = CLGeocoder() // Deprecated/Unused
    private var locationContinuation: CheckedContinuation<LocationResult, Error>?
    private var timeoutTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        updateAuthorizationStatus()
        print("[LocationManager] Initialized, status: \(authorizationStatus.rawValue)")
    }
    
    // MARK: - Public Methods
    
    /// 请求位置权限（When In Use）
    func requestAuthorization() {
        print("[LocationManager] Requesting authorization...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// 获取当前位置（带 5 秒超时）
    /// - Returns: 位置结果（不含国家代码）
    func getCurrentLocation() async throws -> LocationResult {
        print("[LocationManager] 📍 Getting current location...")
        
        // 检查权限
        if authorizationStatus == .notDetermined {
            print("[LocationManager] Authorization not determined, requesting...")
            requestAuthorization()
            
            // 等待授权结果（最多 3 秒）
            try await Task.sleep(nanoseconds: 3_000_000_000)
            updateAuthorizationStatus()
        }
        
        guard isAuthorized else {
            print("[LocationManager] ❌ Not authorized: \(authorizationStatus.rawValue)")
            throw LocationError.denied
        }
        
        // 如果正在定位，等待结果
        if isLocating {
            print("[LocationManager] Already locating, waiting...")
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        isLocating = true
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: LocationError.unavailable)
                return
            }
            
            self.locationContinuation = continuation
            
            // 启动定位
            self.locationManager.requestLocation()
            
            // 设置超时
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.locationTimeout ?? 5.0) * 1_000_000_000)
                
                await MainActor.run {
                    if let continuation = self?.locationContinuation {
                        print("[LocationManager] ⏰ Location timeout after \(self?.locationTimeout ?? 5)s")
                        self?.isLocating = false
                        self?.locationContinuation = nil
                        continuation.resume(throwing: LocationError.timeout)
                    }
                }
            }
        }
    }
    
    /// 获取位置并判断国家（用于选择天气供应商）
    /// - Returns: 位置结果（含国家代码）
    func getLocationWithCountry() async throws -> LocationResult {
        var result = try await getCurrentLocation()
        
        // 尝试反向地理编码获取国家代码
        result.isoCountryCode = await getCountryCode(for: result.coordinate)
        
        print("[LocationManager] 📍 Location with country: \(result.coordinate.latitude), \(result.coordinate.longitude), country: \(result.isoCountryCode ?? "unknown")")
        
        return result
    }
    
    /// 仅获取国家代码（使用备用方案）
    func getCountryCode(for coordinate: CLLocationCoordinate2D) async -> String? {
        // 备用：使用设备区域
        if let regionCode = Locale.current.region?.identifier {
            print("[LocationManager] 🌍 Country code from locale: \(regionCode)")
            return regionCode
        }
        
        print("[LocationManager] 🌍 Country code: unknown, defaulting to international")
        return nil
    }
    
    // MARK: - Private Methods
    
    private func updateAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 取消超时任务
        timeoutTask?.cancel()
        timeoutTask = nil
        
        guard let location = locations.last else {
            locationContinuation?.resume(throwing: LocationError.unavailable)
            locationContinuation = nil
            isLocating = false
            return
        }
        
        let result = LocationResult(
            coordinate: location.coordinate,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
        
        lastLocation = result
        isLocating = false
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        
        print("[LocationManager] ✅ Location received:")
        print("   坐标: \(result.coordinate.latitude), \(result.coordinate.longitude)")
        print("   精度: \(result.accuracy)m")
        print("   时间: \(formatter.string(from: result.timestamp))")
        
        locationContinuation?.resume(returning: result)
        locationContinuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 取消超时任务
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // 如果已经返回了位置（continuation 已被消费），忽略后续错误
        // 这在 iOS Simulator 中很常见
        guard locationContinuation != nil else {
            print("[LocationManager] ⚠️ Ignoring late error (location already received): \(error.localizedDescription)")
            return
        }
        
        print("[LocationManager] ❌ Location error: \(error)")
        
        isLocating = false
        
        let locationError: LocationError
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .denied
            case .locationUnknown:
                locationError = .unavailable
            default:
                locationError = .unknown(error)
            }
        } else {
            locationError = .unknown(error)
        }
        
        locationContinuation?.resume(throwing: locationError)
        locationContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        updateAuthorizationStatus()
        print("[LocationManager] 🔐 Authorization changed: \(oldStatus.rawValue) → \(authorizationStatus.rawValue)")
    }
}
