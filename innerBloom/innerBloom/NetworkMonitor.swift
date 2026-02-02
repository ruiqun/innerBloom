//
//  NetworkMonitor.swift
//  innerBloom
//
//  网络状态监测 - B-004
//  负责：检测网络连接状态、通知状态变化
//

import Foundation
import Network

/// 网络状态
enum NetworkStatus {
    case connected      // 已连接
    case disconnected   // 未连接
    case unknown        // 未知
}

/// 网络监测器
/// 使用 @Observable 宏，可被 SwiftUI 视图观察
@Observable
final class NetworkMonitor {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Properties
    
    /// 当前网络状态
    private(set) var status: NetworkStatus = .unknown
    
    /// 是否已连接网络
    var isConnected: Bool {
        status == .connected
    }
    
    /// 连接类型描述
    private(set) var connectionType: String = "Unknown"
    
    // MARK: - Private
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    /// 开始监测网络状态
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateStatus(path)
            }
        }
        monitor.start(queue: queue)
        print("[NetworkMonitor] Started monitoring")
    }
    
    /// 停止监测
    private func stopMonitoring() {
        monitor.cancel()
        print("[NetworkMonitor] Stopped monitoring")
    }
    
    /// 更新网络状态
    private func updateStatus(_ path: NWPath) {
        let oldStatus = status
        
        if path.status == .satisfied {
            status = .connected
            
            // 更新连接类型
            if path.usesInterfaceType(.wifi) {
                connectionType = "WiFi"
            } else if path.usesInterfaceType(.cellular) {
                connectionType = "Cellular"
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = "Ethernet"
            } else {
                connectionType = "Other"
            }
        } else {
            status = .disconnected
            connectionType = "None"
        }
        
        if oldStatus != status {
            print("[NetworkMonitor] Status changed: \(status), type: \(connectionType)")
        }
    }
    
    // MARK: - Utility
    
    /// 等待网络连接（带超时）
    /// - Parameter timeout: 超时时间（秒）
    /// - Returns: 是否连接成功
    func waitForConnection(timeout: TimeInterval = 5) async -> Bool {
        if isConnected { return true }
        
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if isConnected { return true }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
        }
        
        return isConnected
    }
}

// MARK: - 便捷扩展

extension NetworkMonitor {
    /// 执行需要网络的操作
    /// - Parameters:
    ///   - action: 需要执行的操作
    ///   - offlineHandler: 离线时的处理
    func performWithNetwork<T>(
        _ action: () async throws -> T,
        offlineHandler: () -> T
    ) async rethrows -> T {
        if isConnected {
            return try await action()
        } else {
            print("[NetworkMonitor] Offline, using offline handler")
            return offlineHandler()
        }
    }
}
