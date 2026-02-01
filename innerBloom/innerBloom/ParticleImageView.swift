//
//  ParticleImageView.swift
//  innerBloom
//
//  粒子化图片组件
//  核心主视觉：图片被拆解成粒子状，缓慢浮动，移除外围光环
//

import SwiftUI

struct ParticleImageView: View {
    let image: UIImage?
    
    // 粒子配置
    private let particleCount = 200 // 内部浮动粒子数量
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            
            ZStack {
                // 1. 图片主体 (带点阵化 Mask 和边缘消散)
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 280)
                        .clipShape(Circle())
                        // 缓慢浮动动画 (Breathing/Floating)
                        .scaleEffect(1.0 + sin(now * 0.5) * 0.02)
                        .offset(y: sin(now * 0.3) * 5)
                        .mask(
                            // 径向渐变 Mask 实现边缘柔和/侵蚀效果
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.6), // 中心完全不透明
                                    .init(color: .black.opacity(0.8), location: 0.8),
                                    .init(color: .clear, location: 1.0) // 边缘完全透明
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .overlay(
                            // 叠加一层点阵纹理，模拟“拆解成粒子”的质感
                            Image(systemName: "circle.fill") // 使用简单的点阵图或 Shader 会更好，这里用 Overlay 模拟
                                .resizable()
                                .foregroundColor(.white.opacity(0.05))
                                .blendMode(.overlay)
                        )
                } else {
                    // 空状态
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 280, height: 280)
                        .overlay(
                            Text("Tap to Upload")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        )
                }
                
                // 2. 内部浮动粒子 (模拟图片正在分解/能量流动)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = size.width / 2 * 0.8 // 限制在图片内部
                    
                    for i in 0..<particleCount {
                        let seed = Int(now * 0.05) + i
                        
                        // 随机位置 (限制在圆内)
                        let angle = Double(i) * (360.0 / Double(particleCount)) * .pi / 180
                        let dist = Double.random(in: 0...1) * radius
                        
                        // 动态偏移
                        let xOffset = cos(now * 0.2 + Double(i)) * 10
                        let yOffset = sin(now * 0.3 + Double(i)) * 10
                        
                        let x = center.x + cos(angle) * dist + xOffset
                        let y = center.y + sin(angle) * dist + yOffset
                        
                        // 粒子大小与透明度
                        let particleSize = Double.random(in: 1...2)
                        let opacity = Double.random(in: 0.1...0.4) * abs(sin(now + Double(i)))
                        
                        let particleRect = CGRect(
                            x: x - particleSize / 2,
                            y: y - particleSize / 2,
                            width: particleSize,
                            height: particleSize
                        )
                        
                        context.opacity = opacity
                        context.fill(
                            Path(ellipseIn: particleRect),
                            with: .color(.white) // 使用白色粒子叠加，模拟高光
                        )
                    }
                }
                .frame(width: 280, height: 280)
                .blendMode(.overlay) // 叠加模式，让粒子融入图片
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ParticleImageView(image: UIImage(systemName: "photo"))
    }
}
