//
//  innerBloomApp.swift
//  innerBloom
//
//  Created by Jeff Zheng on 2026/1/31.
//
//  B-010: App 启动时自动触发环境刷新（定位+天气）
//  B-018: App 启动时判断登入状态，未登入显示 LoginView
//

import SwiftUI

@main
struct innerBloomApp: App {
    
    /// 环境服务（App 级别单例）
    private let environmentService = EnvironmentService.shared
    
    /// 认证管理器 (B-018)
    @Bindable private var authManager = AuthManager.shared
    
    /// 设置管理器（用于全局外观模式）
    @Bindable private var settingsManager = SettingsManager.shared
    
    /// 场景阶段监听
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            // B-018: 根据登入状态显示不同页面
            Group {
                switch authManager.authState {
                case .unknown:
                    // 启动中，显示 splash
                    splashView
                    
                case .unauthenticated:
                    // 未登入，显示登入页 (S-004)
                    LoginView()
                        .transition(.opacity)
                    
                case .authenticated:
                    // 已登入，显示主页 (S-001)
                    ContentView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.authState)
            .preferredColorScheme(settingsManager.colorScheme)
            .onChange(of: authManager.authState) { _, newState in
                // B-018: 登入成功後從雲端重新載入回憶（修復登出再登入後回憶消失問題）
                if newState == .authenticated {
                    HomeViewModel.shared.reloadAfterLogin()
                }
            }
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
    
    /// 启动画面（认证状态未确定时显示）
    private var splashView: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.accent)
                    .shadow(color: Theme.goldLight.opacity(0.3), radius: 10, x: 0, y: 0)
                
                Text("InnerBloom")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .tracking(2)
                    .foregroundColor(Theme.textPrimary)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(0.8)
                    .padding(.top, 8)
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
