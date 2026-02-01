//
//  ParticleImageView.swift
//  innerBloom
//
//  粒子化图片组件
//  核心主视觉：图片被拆解成粒子状，缓慢浮动
//

import SwiftUI

struct ParticleImageView: View {
    let image: UIImage?
    
    // 粒子配置
    private let particleCount = 180 // 配合尺寸变大，略微增加粒子
    
    // 尺寸配置
    private let imageSize: CGFloat = UIScreen.main.bounds.width - 48 // 左右各留 24pt
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let radius = imageSize / 2
            
            ZStack {
                // 1. 图片主体 (带点阵化 Mask 和边缘消散)
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(Circle())
                        // 缓慢浮动动画
                        .scaleEffect(1.0 + sin(now * 0.5) * 0.01)
                        .offset(y: sin(now * 0.3) * 3)
                        .mask(
                            // 径向渐变 Mask
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.6),
                                    .init(color: .black.opacity(0.8), location: 0.8),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                } else {
                    // 空状态
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: imageSize, height: imageSize)
                        .overlay(
                            Text("Tap to Upload")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        )
                }
                
                // 2. 内部浮动粒子 (仅白色，仅内部)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let particleRadius = size.width / 2 * 0.75 // 严格限制在图片内部
                    
                    for i in 0..<particleCount {
                        // 随机位置
                        let angle = Double(i) * (360.0 / Double(particleCount)) * .pi / 180
                        let dist = Double.random(in: 0...1) * particleRadius
                        
                        // 动态偏移
                        let xOffset = cos(now * 0.2 + Double(i)) * 5
                        let yOffset = sin(now * 0.3 + Double(i)) * 5
                        
                        let x = center.x + cos(angle) * dist + xOffset
                        let y = center.y + sin(angle) * dist + yOffset
                        
                        // 粒子大小与透明度
                        let particleSize = Double.random(in: 1...2.5)
                        let opacity = Double.random(in: 0.1...0.3) * abs(sin(now + Double(i)))
                        
                        let particleRect = CGRect(
                            x: x - particleSize / 2,
                            y: y - particleSize / 2,
                            width: particleSize,
                            height: particleSize
                        )
                        
                        context.opacity = opacity
                        context.fill(
                            Path(ellipseIn: particleRect),
                            with: .color(.white) // 纯白粒子
                        )
                    }
                }
                .frame(width: imageSize, height: imageSize)
                .blendMode(.overlay)
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
