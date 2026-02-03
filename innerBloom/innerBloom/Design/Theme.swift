//
//  Theme.swift
//  innerBloom
//
//  设计系统与主题配置
//  B-016: 支持深色/浅色模式切换
//

import SwiftUI

/// 主题配置
/// B-016: 使用动态颜色支持深浅色模式自动切换
struct Theme {
    // MARK: - 动态颜色（自动适应深浅色模式）
    
    /// 背景色：深色模式为纯黑，浅色模式为浅灰
    static let background = Color("ThemeBackground")
    
    /// 强调色：Emerald/Teal 绿色（保持一致）
    static let accent = Color(red: 0.0, green: 0.8, blue: 0.6)
    
    /// 粒子颜色：冷蓝/青蓝
    static let particleBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    
    /// 主文字颜色：自适应深浅色
    static let textPrimary = Color("ThemeTextPrimary")
    
    /// 次文字颜色：自适应深浅色
    static let textSecondary = Color("ThemeTextSecondary")
    
    /// 玻璃拟态背景：自适应深浅色
    static let surface = Color("ThemeSurface")
    
    /// AI 气泡背景色：自适应深浅色
    static let aiBubbleBackground = Color("ThemeAIBubble")
    
    // MARK: - 固定颜色（深色模式专用，向前兼容）
    
    /// 深色模式背景色
    static let backgroundDark = Color(red: 0.02, green: 0.02, blue: 0.03)
    
    /// 浅色模式背景色
    static let backgroundLight = Color(red: 0.96, green: 0.96, blue: 0.97)
    
    /// 深色模式主文字色
    static let textPrimaryDark = Color(white: 0.95)
    
    /// 浅色模式主文字色
    static let textPrimaryLight = Color(white: 0.1)
    
    /// 深色模式次文字色
    static let textSecondaryDark = Color(white: 0.6)
    
    /// 浅色模式次文字色
    static let textSecondaryLight = Color(white: 0.45)
    
    // MARK: - Gradients
    
    /// 粒子光晕渐变
    static let particleGradient = RadialGradient(
        gradient: Gradient(colors: [
            particleBlue.opacity(0.3),
            particleBlue.opacity(0.1),
            Color.clear
        ]),
        center: .center,
        startRadius: 100,
        endRadius: 300
    )
    
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
    
    /// 强调色发光效果
    func neonGlow(color: Color = Theme.accent, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
    }
}
