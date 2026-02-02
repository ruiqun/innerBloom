//
//  ParticleImageView.swift
//  innerBloom
//
//  圆形图片组件
//  核心主视觉：圆形裁剪 + 边缘消散效果
//

import SwiftUI

struct ParticleImageView: View {
    let image: UIImage?
    
    // 尺寸配置
    private let imageSize: CGFloat = UIScreen.main.bounds.width - 48 // 左右各留 24pt
    
    var body: some View {
        let radius = imageSize / 2
        
        ZStack {
            // 图片主体 (带边缘消散效果)
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
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
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ParticleImageView(image: UIImage(systemName: "photo"))
    }
}
