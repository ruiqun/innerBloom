//
//  Theme.swift
//  innerBloom
//
//  设计系统与主题配置
//  B-016: 支持深色/浅色模式切换
//  V2: Dark Luxury Gold — 黃金色系精品風格升級
//

import SwiftUI

/// 主题配置
/// B-016: 使用动态颜色支持深浅色模式自动切换
/// V2: 配色全面轉為黃金色系（Dark Luxury Gold）
struct Theme {
    // MARK: - 动态颜色（自动适应深浅色模式）
    
    /// 背景色：深色模式為暖黑，浅色模式为浅灰
    static let background = Color("ThemeBackground")
    
    /// 強調色：霧面金 / 香檳金（Matte Champagne Gold）
    static let accent = Color(red: 0.788, green: 0.659, blue: 0.298)
    
    /// 淡金色：用於極低不透明度的裝飾、光暈
    static let goldLight = Color(red: 0.85, green: 0.75, blue: 0.45)
    
    /// 深金色：用於按下狀態、邊框等需要更深金色的場景
    static let goldDeep = Color(red: 0.667, green: 0.525, blue: 0.204)
    
    /// 粒子颜色：暖琥珀金（取代冷藍）
    static let particleGold = Color(red: 0.78, green: 0.65, blue: 0.25)
    
    /// 主文字颜色：自适应深浅色（暖白）
    static let textPrimary = Color("ThemeTextPrimary")
    
    /// 次文字颜色：自适应深浅色（灰金/暖灰）
    static let textSecondary = Color("ThemeTextSecondary")
    
    /// 玻璃拟态背景：自适应深浅色
    static let surface = Color("ThemeSurface")
    
    /// AI 气泡背景色：自适应深浅色
    static let aiBubbleBackground = Color("ThemeAIBubble")
    
    // MARK: - 向前兼容：保留舊名稱別名
    
    /// 粒子颜色（向前兼容別名）
    static let particleBlue = particleGold
    
    // MARK: - 固定颜色（深色模式专用，向前兼容）
    
    /// 深色模式背景色（暖黑，帶微暖色調）
    static let backgroundDark = Color(red: 0.051, green: 0.047, blue: 0.035)
    
    /// 浅色模式背景色
    static let backgroundLight = Color(red: 0.96, green: 0.955, blue: 0.945)
    
    /// 深色模式主文字色（偏暖白 #F2F0EB）
    static let textPrimaryDark = Color(red: 0.949, green: 0.941, blue: 0.922)
    
    /// 浅色模式主文字色
    static let textPrimaryLight = Color(white: 0.1)
    
    /// 深色模式次文字色（灰金/暖灰 #A8A39A）
    static let textSecondaryDark = Color(red: 0.659, green: 0.639, blue: 0.604)
    
    /// 浅色模式次文字色
    static let textSecondaryLight = Color(white: 0.45)
    
    // MARK: - Gradients
    
    /// 粒子光晕渐变（暖金色調）
    static let particleGradient = RadialGradient(
        gradient: Gradient(colors: [
            particleGold.opacity(0.25),
            particleGold.opacity(0.08),
            Color.clear
        ]),
        center: .center,
        startRadius: 100,
        endRadius: 300
    )
    
    /// 背景暖黑漸層（從深黑到深棕黑）
    static let warmBlackGradient = LinearGradient(
        colors: [
            Color(red: 0.043, green: 0.043, blue: 0.035),
            Color(red: 0.078, green: 0.067, blue: 0.043)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - 字体（与 InnerBloom 标题一致，列表预览等复用）
    
    /// 应用标题字体：16pt、medium、serif（用于「InnerBloom」及日记列表预览等）
    static func titleFont() -> Font {
        .system(size: 16, weight: .medium, design: .serif)
    }
    
    /// 标题字间距
    static let titleTracking: CGFloat = 2
    
    /// 列表辅助字体：serif 小号（日期、底部提示等，与标题风格协调）
    static func listAuxiliaryFont() -> Font {
        .system(size: 12, weight: .regular, design: .serif)
    }
    
    // MARK: - Styles
    
    /// Glassmorphism 背景材质
    static let glassMaterial: Material = .ultraThinMaterial
    
    // MARK: - B-016: 自适应颜色辅助方法
    
    /// 根据外观模式获取背景色
    static func adaptiveBackground(for colorScheme: ColorScheme?) -> Color {
        switch colorScheme {
        case .light:
            return backgroundLight
        case .dark, .none:
            return backgroundDark
        @unknown default:
            return backgroundDark
        }
    }
    
    /// 根据外观模式获取主文字色
    static func adaptiveTextPrimary(for colorScheme: ColorScheme?) -> Color {
        switch colorScheme {
        case .light:
            return textPrimaryLight
        case .dark, .none:
            return textPrimaryDark
        @unknown default:
            return textPrimaryDark
        }
    }
    
    /// 根据外观模式获取次文字色
    static func adaptiveTextSecondary(for colorScheme: ColorScheme?) -> Color {
        switch colorScheme {
        case .light:
            return textSecondaryLight
        case .dark, .none:
            return textSecondaryDark
        @unknown default:
            return textSecondaryDark
        }
    }
}

// MARK: - View Extensions

extension View {
    /// 应用主背景色
    func appBackground() -> some View {
        self.background(Theme.background)
    }
    
    /// 金色柔和發光效果（取代 neonGlow）
    func neonGlow(color: Color = Theme.accent, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.4), radius: radius, x: 0, y: 0)
    }
    
    /// 金色光暈效果（極低強度，精品招牌燈感）
    func goldGlow(radius: CGFloat = 15, opacity: Double = 0.2) -> some View {
        self.shadow(color: Theme.goldLight.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}
