//
//  CircleImageView.swift
//  innerBloom
//
//  圆形图片组件
//  核心主视觉：圆形粒子网格 + 边缘消散粒子效果 + 呼吸波动动画
//  使用 pic2Particle 引擎替代简单圆形裁剪
//

import SwiftUI
import SceneKit

struct CircleImageView: View {
    let image: UIImage?
    
    @StateObject private var particleManager = ParticleManager()
    @State private var lastImageId: String?
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                if image != nil {
                    // 粒子效果视图 - 占满容器，粒子引擎内部已处理圆形裁剪与边缘飞散
                    ParticleSceneView(particleManager: particleManager)
                        .frame(width: size, height: size)
                } else {
                    // 空状态 - Royal Minimal 风格
                    let viewSize = max(size - 52, 100)
                    ZStack {
                        // 1. 深色半透明玻璃底
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .background(.ultraThinMaterial, in: Circle())
                            // 内阴影效果通过 Overlay 实现
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.5), lineWidth: 4)
                                    .blur(radius: 4)
                                    .offset(x: 2, y: 2)
                                    .mask(Circle().fill(LinearGradient(colors: [.clear, .black], startPoint: .topLeading, endPoint: .bottomTrailing)))
                            )
                        
                        // 2. 极细金色描边 (1px) + 外圈月桂叶装饰 (加大并布满整圈)
                        ZStack {
                            Circle()
                                .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                            
                            // 外圈月桂叶环绕 - 皇家花环效果
                            ForEach(0..<45) { i in
                                VStack {
                                    Image(systemName: "laurel.leading")
                                        .font(.system(size: 25, weight: .light)) // 加大尺寸
                                        .foregroundColor(Theme.accent.opacity(0.6))
                                        .rotationEffect(.degrees(90)) // 调整角度使其沿圆切线方向自然衔接
                                        .offset(y: 0) // 微调位置以完美贴合圆环
                                    Spacer()
                                }
                                .frame(width: viewSize, height: viewSize)
                                .rotationEffect(.degrees(Double(i) * 8)) // 360 / 24 = 15度间隔，更密集
                            }
                        }
                        
                        // 3. 淡淡金色光晕 (精品灯感)
                        Circle()
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 15, x: 0, y: 0)
                        
                        // 4. 内容：皇家极简徽章 + 文字
                        VStack(spacing: 12) {
                            // 极简徽章组合
                            VStack(spacing: 4) {
                                // 顶部小皇冠
                                Image(systemName: "crown")
                                    .font(.system(size: 25, weight: .light))
                                    .foregroundColor(Theme.accent)
                                
                                // 装饰线
                                Rectangle()
                                    .fill(Theme.goldLinearGradient)
                                    .frame(width: 20, height: 1)
                            }
                            
                            Text(String.localized(.tapToUpload))
                                .font(Theme.royalFont(size: 14, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2) // 增加字间距提升高级感
                        }
                    }
                    .frame(width: viewSize, height: viewSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: image) { _, newImage in
            updateParticles(newImage)
        }
        .onAppear {
            updateParticles(image)
        }
    }
    
    /// 当图片变化时更新粒子网格
    private func updateParticles(_ uiImage: UIImage?) {
        guard let uiImage = uiImage else { return }
        
        // 避免重复生成
        let imageId = "\(uiImage.size.width)x\(uiImage.size.height)_\(uiImage.hash)"
        guard imageId != lastImageId else { return }
        lastImageId = imageId
        
        // 在后台线程生成网格，避免卡顿
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                particleManager.createMesh(from: uiImage)
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CircleImageView(image: UIImage(systemName: "photo"))
    }
}
