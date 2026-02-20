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
    
    /// 強調色：香檳金（Champagne Gold）- #D4AF37
    static let accent = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    /// 淡金色：用於極低不透明度的裝飾、光暈 - #E5D395
    static let goldLight = Color(red: 0.898, green: 0.827, blue: 0.584)
    
    /// 深金色：用於按下狀態、邊框等需要更深金色的場景 - #C8A24A
    static let goldDeep = Color(red: 0.784, green: 0.635, blue: 0.290)
    
    /// 粒子颜色：暖琥珀金
    static let particleGold = Color(red: 0.831, green: 0.686, blue: 0.216)
    
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
    
    /// 深色模式背景色（暖黑 #0B0B0C）
    static let backgroundDark = Color(red: 0.043, green: 0.043, blue: 0.047)
    
    /// 浅色模式背景色
    static let backgroundLight = Color(red: 0.96, green: 0.955, blue: 0.945)
    
    /// 深色模式主文字色（暖白 #F2F0EB）
    static let textPrimaryDark = Color(red: 0.949, green: 0.941, blue: 0.922)
    
    /// 浅色模式主文字色
    static let textPrimaryLight = Color(white: 0.1)
    
    /// 深色模式次文字色（暖灰 #A8A39A）
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
    
    /// 背景暖黑漸層（#0B0B0C -> #14110B）
    static let warmBlackGradient = LinearGradient(
        colors: [
            Color(red: 0.043, green: 0.043, blue: 0.047), // #0B0B0C
            Color(red: 0.078, green: 0.067, blue: 0.043)  // #14110B
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// 金色线性渐变（模拟金属光泽）
    static let goldLinearGradient = LinearGradient(
        colors: [
            Color(red: 0.784, green: 0.635, blue: 0.290), // Dark Gold
            Color(red: 0.898, green: 0.827, blue: 0.584), // Light Gold
            Color(red: 0.831, green: 0.686, blue: 0.216)  // Accent Gold
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - 字体（与 InnerBloom 标题一致，列表预览等复用）
    
    /// 皇家衬线体（用于强调、标题、仪式感文字）
    static func royalFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    
    /// 應用標題字體：16pt、medium、serif（用於主頁「InnerBloom」標題與日記列表預覽等；改大小請改 16）
    static func titleFont() -> Font {
        royalFont(size: 16, weight: .medium)
    }
    
    /// 標題字距（主頁 InnerBloom 標題用）
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
