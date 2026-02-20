//
//  SettingsView.swift
//  innerBloom
//
//  设定页面 - S-003
//  B-016: 深色模式与多语言预留
//  B-017: 多语言功能实现
//  B-018: 添加帐号区块与登出按钮
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settingsManager = SettingsManager.shared
    @Bindable private var localization = LocalizationManager.shared
    @Bindable private var authManager = AuthManager.shared  // B-018
    @Bindable private var iapManager = IAPManager.shared    // B-023
    @State private var showLogoutConfirm = false  // B-018
    @State private var showPremium = false        // B-023
    @State private var showCompanionRoleSheet = false  // B-029 S-007
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // B-018: 帐号区块
                        accountSection
                        
                        // B-023: Premium 入口
                        premiumSection
                        
                        // B-016: 外观设定暂时隐藏，强制使用深色模式
                        // appearanceSection
                        
                        // AI 设定
                        aiSection
                        
                        // 语言设定
                        languageSection
                        
                        // 隐私设定
                        privacySection
                        
                        // 关于
                        aboutSection
                        
                        // 开发者设定（条件显示）
                        if DevConfig.isDevelopmentMode {
                            developerSection
                        }
                        
                        // 底部留白
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(String.localized(.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String.localized(.done)) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .preferredColorScheme(settingsManager.colorScheme)
        // B-017: 监听语言变化
        .id(localization.languageChangeId)
        // B-018: 登出确认对话框
        .sheet(isPresented: $showPremium) {
            PremiumView()
        }
        .sheet(isPresented: $showCompanionRoleSheet) {
            CompanionRoleSheet()
        }
        .alert(String.localized(.logoutConfirm), isPresented: $showLogoutConfirm) {
            Button(String.localized(.cancel), role: .cancel) { }
            Button(String.localized(.logout), role: .destructive) {
                performLogout()
            }
        } message: {
            Text(String.localized(.logoutConfirmDesc))
        }
    }
    
    // MARK: - 外观设定
    
    private var appearanceSection: some View {
        SettingsSection(title: String.localized(.appearance), icon: "paintbrush.fill") {
            VStack(spacing: 12) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    SettingsOptionRow(
                        title: mode.displayName,
                        icon: mode.icon,
                        isSelected: settingsManager.appearanceMode == mode
                    ) {
                        settingsManager.setAppearanceMode(mode)
                    }
                }
            }
        }
    }
    
    // MARK: - 帐号区块 (B-018)
    
    private var accountSection: some View {
        SettingsSection(title: String.localized(.account), icon: "person.circle.fill") {
            VStack(spacing: 12) {
                // 当前帐号信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String.localized(.currentAccount))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(authManager.currentUserEmail ?? String.localized(.notLoggedIn))
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                    
                    // 登入状态指示
                    HStack(spacing: 6) {
                        Circle()
                            .fill(authManager.isAuthenticated ? Theme.accent : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(authManager.isAuthenticated
                             ? String.localized(.connected)
                             : String.localized(.notLoggedIn))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                if authManager.isAuthenticated {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // 登出按钮
                    Button(action: {
                        showLogoutConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.8))
                            
                            Text(String.localized(.logout))
                                .font(.system(size: 15))
                                .foregroundColor(.red.opacity(0.8))
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Premium 區塊 (B-023)
    
    private var premiumSection: some View {
        SettingsSection(title: String.localized(.premium), icon: "crown.fill") {
            if iapManager.premiumStatus.isPremium {
                Button(action: { showManageSubscriptions() }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String.localized(.premiumAlreadySubscribed))
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textPrimary)
                            if let expiresAt = iapManager.premiumStatus.expiresAt {
                                Text("\(String.localized(.premiumExpiresOn)): \(formatExpiryDate(expiresAt))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Text(String.localized(.manageSubscription))
                                .font(.system(size: 13))
                                .foregroundColor(Theme.accent)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showPremium = true }) {
                    HStack {
                        Text(String.localized(.upgradePremium))
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// 执行登出 (B-018)
    private func performLogout() {
        Task {
            // 1. 清理 HomeViewModel 数据
            await MainActor.run {
                HomeViewModel.shared.resetForLogout()
            }
            
            // 2. 调用 AuthManager 登出
            await authManager.signOut()
            
            // 3. 关闭设定页
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    // MARK: - AI 设定（B-029: 陪伴角色）
    
    private var aiSection: some View {
        SettingsSection(title: String.localized(.aiAssistant), icon: "sparkles") {
            VStack(spacing: 16) {
                // B-029: 陪伴角色（S-007 入口）
                Button(action: { showCompanionRoleSheet = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String.localized(.companionRole))
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textPrimary)
                            Text("\(settingsManager.aiToneStyle.roleName)｜\(settingsManager.aiToneStyle.roleTag)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                SettingsToggleRow(
                    title: String.localized(.autoGenerateTags),
                    subtitle: String.localized(.autoGenerateTagsDesc),
                    isOn: Binding(
                        get: { settingsManager.autoGenerateTags },
                        set: { settingsManager.setAutoGenerateTags($0) }
                    )
                )
            }
        }
    }
    
    // MARK: - 语言设定
    
    private var languageSection: some View {
        SettingsSection(title: String.localized(.language), icon: "globe") {
            VStack(spacing: 12) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    SettingsOptionRow(
                        title: "\(language.flag) \(language.displayName)",
                        isSelected: settingsManager.appLanguage == language
                    ) {
                        settingsManager.setAppLanguage(language)
                    }
                }
                
                // B-017: 提示文字（语言切换即时生效）
                Text(String.localized(.languageChangeNote))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - 隐私设定
    
    private var privacySection: some View {
        SettingsSection(title: String.localized(.privacy), icon: "lock.fill") {
            VStack(spacing: 16) {
                // 媒體分析已移除：預設一律提供，無開關
                SettingsToggleRow(
                    title: String.localized(.allowLocationSharing),
                    subtitle: String.localized(.allowLocationSharingDesc),
                    isOn: Binding(
                        get: { settingsManager.allowLocationSharing },
                        set: { settingsManager.setAllowLocationSharing($0) }
                    )
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 隐私说明
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    HStack {
                        Text(String.localized(.privacyPolicy))
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 关于
    
    private var aboutSection: some View {
        SettingsSection(title: String.localized(.about), icon: "info.circle.fill") {
            VStack(spacing: 12) {
                // App 版本
                HStack {
                    Text(String.localized(.version))
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Text(appVersion)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
                
                // 构建号
                HStack {
                    Text(String.localized(.buildNumber))
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Text(buildNumber)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 重置设定
                Button(action: {
                    settingsManager.resetSettings()
                    // B-017: 重置后同步语言
                    localization.syncFromSettings()
                }) {
                    HStack {
                        Text(String.localized(.resetAllSettings))
                            .font(.system(size: 15))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 开发者设定
    
    private var developerSection: some View {
        SettingsSection(title: String.localized(.developer), icon: "hammer.fill") {
            VStack(spacing: 16) {
                SettingsToggleRow(
                    title: String.localized(.showModelInfo),
                    subtitle: String.localized(.showModelInfoDesc),
                    isOn: Binding(
                        get: { settingsManager.showModelInfo },
                        set: { settingsManager.setShowModelInfo($0) }
                    )
                )
                
                // 当前模型信息（只读）
                HStack {
                    Text(String.localized(.currentModel))
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Text("ChatGPT")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.accent)
                }
                
                // Supabase 状态
                HStack {
                    Text(String.localized(.cloudService))
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(SupabaseConfig.shared.isConfigured ? Theme.accent : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(SupabaseConfig.shared.isConfigured ? String.localized(.connected) : String.localized(.notConfigured))
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 辅助
    
    private func formatExpiryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = .current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    private func showManageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        Task {
            try? await AppStore.showManageSubscriptions(in: scene)
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - 设定分组容器

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - 选项行

struct SettingsOptionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标（可选）
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                        .frame(width: 20)
                }
                
                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 开关行

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.accent)
        }
    }
}

// MARK: - 隐私政策页面
// B-017: 支持多语言

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var localization = LocalizationManager.shared
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(String.localized(.privacyPolicyTitle))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Group {
                        privacySection(String.localized(.dataCollection), content: String.localized(.dataCollectionContent))
                        
                        privacySection(String.localized(.dataUsage), content: String.localized(.dataUsageContent))
                        
                        privacySection(String.localized(.dataSecurity), content: String.localized(.dataSecurityContent))
                        
                        privacySection(String.localized(.yourRights), content: String.localized(.yourRightsContent))
                    }
                    
                    Text(String.localized(.lastUpdated))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 20)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .id(localization.languageChangeId)
    }
    
    private func privacySection(_ title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
