//
//  MediaAreaView.swift
//  innerBloom
//
//  媒体区组件 - F-001
//

import SwiftUI

/// 媒体区视图
/// 对应 F-001：新增日记（选照片/影片）
struct MediaAreaView: View {
    
    // MARK: - Properties
    
    /// 选中的媒体图片
    let selectedImage: UIImage?
    
    /// 选择媒体的回调
    let onSelectMedia: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if let image = selectedImage {
                // 已选择媒体 - 显示预览
                mediaPreviewView(image: image)
            } else {
                // 未选择媒体 - 显示引导
                selectMediaPromptView
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - 子视图
    
    /// 媒体预览视图
    private func mediaPreviewView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()
            .cornerRadius(16)
            .overlay(
                // 重新选择按钮
                Button(action: {
                    print("[MediaAreaView] Reselet media tapped")
                    onSelectMedia()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(12),
                alignment: .topTrailing
            )
    }
    
    /// 选择媒体引导视图
    private var selectMediaPromptView: some View {
        Button(action: {
            print("[MediaAreaView] Select media tapped")
            onSelectMedia()
        }) {
            VStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
                
                // 文字提示
                Text("选择照片或影片")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("点击此处从相簿选择")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择照片或影片")
    }
}

// MARK: - Preview

#Preview("媒体区 - 未选择") {
    MediaAreaView(
        selectedImage: nil,
        onSelectMedia: {
            print("Select media tapped")
        }
    )
    .padding()
}

#Preview("媒体区 - 已选择") {
    // 创建一个示例图片用于预览
    let sampleImage = UIImage(systemName: "photo.fill")?
        .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
    
    return MediaAreaView(
        selectedImage: sampleImage,
        onSelectMedia: {
            print("Reselect media tapped")
        }
    )
    .padding()
}
