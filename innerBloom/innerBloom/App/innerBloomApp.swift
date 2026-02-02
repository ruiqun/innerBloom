//
//  innerBloomApp.swift
//  innerBloom
//
//  Created by Jeff Zheng on 2026/1/31.
//
//  B-010: App 启动时自动触发环境刷新（定位+天气）
//

import SwiftUI

@main
struct innerBloomApp: App {
    
    /// 环境服务（App 级别单例）
    private let environmentService = EnvironmentService.shared
    
    /// 场景阶段监听
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
                .onAppear {
                    // App 首次启动
                    print("[App] 🚀 innerBloom launched")
                    environmentService.onAppBecomeActive()
                }
        }
    }
    
    /// 处理场景阶段变化
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App 进入前台
            if oldPhase != .active {
                print("[App] 📱 App became active (from \(oldPhase))")
                environmentService.onAppBecomeActive()
            }
            
        case .inactive:
            print("[App] 📱 App became inactive")
            
        case .background:
            print("[App] 📱 App entered background")
            
        @unknown default:
            break
        }
    }
}
