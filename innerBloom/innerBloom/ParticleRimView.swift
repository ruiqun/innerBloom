//
//  ParticleRimView.swift
//  innerBloom
//
//  粒子能量晕圈效果组件
//  核心主视觉：图片边缘被细密星尘/雪雾粒子包裹，粒子侵蚀式过渡
//

import SwiftUI

struct ParticleRimView: View {
    let image: UIImage?
    
    @State private var time: TimeInterval = 0
    
    // 粒子配置
    private let particleCount = 400
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // 基础半径，略小于视图宽度的一半，留出粒子扩散空间
                let baseRadius = min(size.width, size.height) / 2 * 0.75
                
                // 1. 绘制粒子光环 (Particle Rim)
                for i in 0..<particleCount {
                    // 随机种子
                    var rng = SystemRandomNumberGenerator()
                    let seed = Int(now * 0.1) + i // 随时间缓慢变化的种子，或者静态种子+动态偏移
                    
                    // 为了性能和稳定性，我们使用伪随机但确定的位置，加上动态扰动
                    let angle = Double(i) * (360.0 / Double(particleCount)) * .pi / 180
                    
                    // 动态呼吸效果
                    let breathing = sin(now * 0.5 + Double(i) * 0.1) * 5.0
                    
                    // 粒子分布：从边缘向外密度渐变
                    // 使用指数分布或高斯分布模拟 "近处更密，向外稀疏"
                    let spread = Double.random(in: 0...1)
                    let distanceOffset = pow(spread, 3) * 60.0 // 越往外越少
                    
                    let radius = baseRadius + distanceOffset + breathing
                    
                    let x = center.x + cos(angle) * radius
                    let y = center.y + sin(angle) * radius
                    
                    // 粒子大小与透明度
                    let particleSize = Double.random(in: 1...3)
                    let opacity = (1.0 - spread) * 0.8 * abs(sin(now * 2 + Double(i))) // 闪烁
                    
                    let particleRect = CGRect(
                        x: x - particleSize / 2,
                        y: y - particleSize / 2,
                        width: particleSize,
                        height: particleSize
                    )
                    
                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: particleRect),
                        with: .color(Theme.particleBlue.opacity(0.6))
                    )
                }
            }
        }
        .background(
            // 2. 底层光晕 (Bloom)
            ZStack {
                Circle()
                    .fill(Theme.particleBlue.opacity(0.15))
                    .frame(width: 320, height: 320)
                    .blur(radius: 40)
                
                Circle()
                    .stroke(Theme.particleBlue.opacity(0.3), lineWidth: 1)
                    .frame(width: 280, height: 280)
                    .blur(radius: 10)
            }
        )
        .overlay(
            // 3. 图片主体 (带侵蚀 Mask)
            Group {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 260, height: 260) // 略小于光环
                        .clipShape(Circle())
                        .mask(
                            // 径向渐变 Mask 实现边缘柔和/侵蚀效果
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.7), // 中心完全不透明
                                    .init(color: .black.opacity(0.5), location: 0.85),
                                    .init(color: .clear, location: 1.0) // 边缘完全透明
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 130 // 对应 frame width/2
                            )
                        )
                        .overlay(
                            // 叠加一层噪点纹理增加质感 (Optional)
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .blendMode(.overlay)
                        )
                } else {
                    // 空状态：显示一个神秘的空洞
                    Circle()
                        .fill(Color.black)
                        .frame(width: 260, height: 260)
                        .overlay(
                            Text("Tap to Upload")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        )
                }
            }
        )
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ParticleRimView(image: UIImage(systemName: "photo"))
    }
}
