//
//  ParticleSceneView.swift
//  innerBloom
//
//  SceneKit 粒子渲染视图
//  从 pic2Particle 项目移植
//  支持捏合缩放 + 双指旋转（roll/pitch 限幅）
//

import SwiftUI
import SceneKit

struct ParticleSceneView: UIViewRepresentable {
    let particleManager: ParticleManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(particleManager: particleManager)
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = particleManager.scene
        scnView.allowsCameraControl = false  // 使用自定义手势
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = ParticleManager.sceneBackgroundColor
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        
        // 添加自定义手势
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        scnView.addGestureRecognizer(pinchGesture)
        
        let rotationGesture = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation(_:)))
        scnView.addGestureRecognizer(rotationGesture)
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        scnView.addGestureRecognizer(panGesture)
        
        // 允许手势同时识别
        pinchGesture.delegate = context.coordinator
        rotationGesture.delegate = context.coordinator
        panGesture.delegate = context.coordinator
        
        context.coordinator.scnView = scnView
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let particleManager: ParticleManager
        weak var scnView: SCNView?
        
        // 缩放限制 (相机 z 范围)
        private let minZoom: Float = 7.0
        private let maxZoom: Float = 14.0
        private var lastScale: CGFloat = 1.0
        
        // 旋转限制 (弧度)
        private let maxPitch: Float = .pi / 8    // ±22.5°
        private let maxYaw: Float = .pi / 8      // ±22.5°
        private let maxRoll: Float = .pi / 6     // ±30°
        
        // 当前角度
        private var currentPitch: Float = 0
        private var currentYaw: Float = 0
        private var currentRoll: Float = 0
        
        // Pan 起始记录
        private var panStartPitch: Float = 0
        private var panStartYaw: Float = 0
        
        init(particleManager: ParticleManager) {
            self.particleManager = particleManager
        }
        
        // 允许同时识别多个手势
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        // MARK: - 捏合缩放
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let cameraNode = particleManager.scene.rootNode.childNode(withName: "camera", recursively: false) else { return }
            
            switch gesture.state {
            case .began:
                lastScale = 1.0
            case .changed:
                let delta = Float(gesture.scale - lastScale)
                lastScale = gesture.scale
                
                // 捏合放大 → z 减小（靠近），捏合缩小 → z 增大（远离）
                var newZ = cameraNode.position.z - delta * 3.0
                newZ = max(minZoom, min(maxZoom, newZ))
                cameraNode.position.z = newZ
            default:
                break
            }
        }
        
        // MARK: - 双指旋转 (Roll)
        
        @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            guard let node = particleManager.geometryNode else { return }
            
            switch gesture.state {
            case .changed:
                let delta = Float(gesture.rotation)
                gesture.rotation = 0
                
                currentRoll += delta
                currentRoll = max(-maxRoll, min(maxRoll, currentRoll))
                
                node.eulerAngles.z = currentRoll
            case .ended, .cancelled:
                // 回弹动画
                withAnimation {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.4
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                    currentRoll *= 0.3  // 松手后回弹至接近原位
                    node.eulerAngles.z = currentRoll
                    SCNTransaction.commit()
                }
            default:
                break
            }
        }
        
        // MARK: - 单指拖动 (Pitch / Yaw)
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let node = particleManager.geometryNode,
                  let view = scnView else { return }
            
            let translation = gesture.translation(in: view)
            let viewSize = view.bounds.size
            
            switch gesture.state {
            case .began:
                panStartPitch = currentPitch
                panStartYaw = currentYaw
            case .changed:
                // 水平拖动 → Yaw，垂直拖动 → Pitch
                let yawDelta = Float(translation.x / viewSize.width) * maxYaw * 2
                let pitchDelta = Float(translation.y / viewSize.height) * maxPitch * 2
                
                currentYaw = max(-maxYaw, min(maxYaw, panStartYaw + yawDelta))
                currentPitch = max(-maxPitch, min(maxPitch, panStartPitch - pitchDelta))
                
                node.eulerAngles.x = currentPitch
                node.eulerAngles.y = currentYaw
            case .ended, .cancelled:
                // 回弹动画
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                currentPitch *= 0.2
                currentYaw *= 0.2
                node.eulerAngles.x = currentPitch
                node.eulerAngles.y = currentYaw
                SCNTransaction.commit()
            default:
                break
            }
        }
    }
}
