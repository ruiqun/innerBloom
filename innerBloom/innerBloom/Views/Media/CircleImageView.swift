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
                    // 空状态 - 保留圆形边框提示
                    let viewSize = max(size - 48, 100)
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: viewSize, height: viewSize)
                        .overlay(
                            Text(String.localized(.tapToUpload))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        )
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
