//
//  Theme.swift
//  innerBloom
//
//  设计系统与主题配置
//

import SwiftUI

struct Theme {
    // MARK: - Colors
    
    /// 背景色：几乎纯黑
    static let background = Color(red: 0.02, green: 0.02, blue: 0.03)
    
    /// 强调色：Emerald/Teal 绿色
    static let accent = Color(red: 0.0, green: 0.8, blue: 0.6)
    
    /// 粒子颜色：冷蓝/青蓝
    static let particleBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    
    /// 文字颜色：灰白克制
    static let textPrimary = Color(white: 0.95)
    static let textSecondary = Color(white: 0.6)
    
    /// 玻璃拟态背景
    static let surface = Color.white.opacity(0.1)
    
    /// AI 气泡背景色
    static let aiBubbleBackground = Color.black.opacity(0.6)
    
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
