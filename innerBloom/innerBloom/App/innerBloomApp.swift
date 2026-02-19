//
//  innerBloomApp.swift
//  innerBloom
//
//  Created by Jeff Zheng on 2026/1/31.
//
//  啟動流程：
//  Splash → 恢復 Session → 已登入則並行預載資料 → 至少 1.2 秒 → 跳轉
//  未登入：Splash 1.2 秒後直接進登入頁
//  手動登入成功：onChange 偵測 → reloadAfterLogin()
//  B-033: 登入後重試待上報 transactions + 從後端同步帳號 Premium 狀態
//

import SwiftUI

@main
struct innerBloomApp: App {
    
    private let environmentService = EnvironmentService.shared
    
    @Bindable private var authManager = AuthManager.shared
    @Bindable private var settingsManager = SettingsManager.shared
    
    @Environment(\.scenePhase) private var scenePhase
    
    /// Splash 是否完成（Session 恢復 + 資料預載 + 最少 1.2 秒）
    @State private var isSplashDone = false
    
    /// 記錄上次 authState，用於偵測「手動登入成功」
    @State private var previousAuthState: AuthState = .unknown
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !isSplashDone {
                    splashView
                } else {
                    switch authManager.authState {
                    case .unknown, .unauthenticated:
                        LoginView()
                            .transition(.opacity)
                    case .authenticated:
                        ContentView()
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isSplashDone)
            .animation(.easeInOut(duration: 0.3), value: authManager.authState)
            .preferredColorScheme(settingsManager.colorScheme)
            .onChange(of: authManager.authState) { oldState, newState in
                // 偵測「手動登入成功」：從登入頁 unauthenticated → authenticated
                if oldState == .unauthenticated && newState == .authenticated && isSplashDone {
                    print("[App] 🔑 Manual login detected, reloading data...")
                    HomeViewModel.shared.reloadAfterLogin()
                    environmentService.onAppBecomeActive()
                    IAPManager.shared.loadCachedStatus()
                    Task {
                        // B-033: 登入後重試待上報 + 從後端同步帳號 Premium
                        await SubscriptionSyncService.shared.retryPendingReports()
                        await IAPManager.shared.syncPremiumStatus()
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            .onAppear {
                LocalizationManager.shared.syncFromSettings()
                print("[App] 🚀 innerBloom launched")
            }
            .task {
                await performSplashSequence()
            }
        }
    }
    
    // MARK: - Splash 啟動流程
    
    /// Splash 期間完整初始化：Session 恢復 → 並行預載 → 最少 1.2 秒
    private func performSplashSequence() async {
        let splashStart = CFAbsoluteTimeGetCurrent()
        let minimumSplashDuration: Double = 1.2
        
        // 1. 恢復 Session（含 token refresh）
        await authManager.restoreSessionAsync()
        
        // 2. 若已登入 → 並行預載資料（Splash 期間完成，進入主頁即有資料）
        if authManager.authState == .authenticated {
            print("[App] ✅ Session valid, preloading data during splash...")
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await HomeViewModel.shared.preloadData()
                }
                group.addTask {
                    EnvironmentService.shared.onAppBecomeActive()
                }
                group.addTask {
                    // B-033: 啟動時重試待上報 + 帳號級別 Premium 同步
                    await SubscriptionSyncService.shared.retryPendingReports()
                    IAPManager.shared.loadCachedStatus()
                    await IAPManager.shared.syncPremiumStatus()
                }
            }
        }
        
        // 3. 確保 Splash 至少顯示 minimumSplashDuration
        let elapsed = CFAbsoluteTimeGetCurrent() - splashStart
        let remaining = minimumSplashDuration - elapsed
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        
        // 4. 結束 Splash → 跳轉
        await MainActor.run {
            isSplashDone = true
            print("[App] 🏁 Splash done (\(String(format: "%.1f", CFAbsoluteTimeGetCurrent() - splashStart))s)")
        }
    }
    
    // MARK: - Splash View
    
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
    
    // MARK: - Scene Phase
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if oldPhase != .active {
                print("[App] 📱 App became active (from \(oldPhase))")
                environmentService.onAppBecomeActive()
                Task { await IAPManager.shared.syncPremiumStatus() }
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
