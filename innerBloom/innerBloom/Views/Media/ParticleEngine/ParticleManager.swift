//
//  ParticleManager.swift
//  innerBloom
//
//  粒子引擎核心 - 图片转粒子网格
//  从 pic2Particle 项目移植
//  圆形裁剪 + 边缘消散粒子效果 + 呼吸波动动画
//

import SwiftUI
import SceneKit
import Combine

class ParticleManager: ObservableObject {
    var scene: SCNScene
    var geometryNode: SCNNode?
    
    /// SCNView 弱引用，用于 prepare() 预编译 Shader
    weak var scnView: SCNView?
    
    // 网格密度
    @Published var gridN: Int = 200
    @Published var gridM: Int = 200
    
    // 呼吸波动参数
    @Published var waveAmplitude: Float = 0.25
    @Published var waveFrequency: Float = 2.0
    @Published var waveSpeed: Float = 1.2
    
    // 粒子参数
    @Published var particleDensity: Float = 0.02
    @Published var particleSize: CGFloat = 2.0
    
    private var currentImage: UIImage?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.scene = SCNScene()
        setupScene()
        setupBindings()
    }
    
    /// 与 Theme.background 深色模式一致的暖黑背景色
    static let sceneBackgroundColor = UIColor(red: 0.051, green: 0.047, blue: 0.035, alpha: 1.0)
    
    private func setupScene() {
        scene.background.contents = ParticleManager.sceneBackgroundColor
        
        // 相机 - z=10 让粒子网格填满视图，y=0 居中避免底部裁切
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 10)
        scene.rootNode.addChildNode(cameraNode)
        
        // 灯光
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLight)
    }
    
    private func setupBindings() {
        $waveAmplitude
            .sink { [weak self] val in
                self?.updateMaterialUniform(key: "amplitude", value: val)
            }
            .store(in: &cancellables)
        
        $waveFrequency
            .sink { [weak self] val in
                self?.updateMaterialUniform(key: "frequency", value: val)
            }
            .store(in: &cancellables)
            
        $waveSpeed
            .sink { [weak self] val in
                self?.updateMaterialUniform(key: "speed", value: val)
            }
            .store(in: &cancellables)
        
        $particleSize
            .sink { [weak self] val in
                self?.updateMaterialUniform(key: "particleSize", value: Float(val))
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest($gridN, $particleDensity)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                if let img = self?.currentImage {
                    self?.createMesh(from: img)
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateMaterialUniform(key: String, value: Float) {
        if let material = geometryNode?.geometry?.firstMaterial {
            material.setValue(value, forKey: key)
        }
        
        if let particlesNode = geometryNode?.childNodes.first,
           let pMat = particlesNode.geometry?.firstMaterial {
            pMat.setValue(value, forKey: key)
        }
    }
    
    /// 原始入口（保留向前相容，內部已改為背景執行）
    func createMesh(from image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.createMeshInBackground(from: image)
        }
    }

    /// 在背景執行緒完成所有 CPU 密集運算，僅在最後回主執行緒掛載節點
    func createMeshInBackground(from image: UIImage) {
        let totalStart = CFAbsoluteTimeGetCurrent()
        print("[ParticleManager] 🔍 createMeshInBackground START — thread: \(Thread.isMainThread ? "⚠️ Main" : "BG"), imageSize: \(image.size)")
        
        let normalizeStart = CFAbsoluteTimeGetCurrent()
        let normalizedImage = image.normalizedOrientation()
        print("[ParticleManager] 🔍 normalizedOrientation: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - normalizeStart) * 1000))ms, result: \(normalizedImage.size)")
        
        let width = Float(normalizedImage.size.width)
        let height = Float(normalizedImage.size.height)
        let aspect = width / height
        
        let targetSize: Float = 10.0
        let worldWidth: Float
        let worldHeight: Float
        if aspect >= 1.0 {
            worldHeight = targetSize
            worldWidth = worldHeight * aspect
        } else {
            worldWidth = targetSize
            worldHeight = worldWidth / aspect
        }
        
        let cols = self.gridN
        let rows = Int(Float(cols) / aspect)
        print("[ParticleManager] 🔍 Grid: \(cols) x \(rows) = \(cols * rows) cells")
        
        let cellSizeX = worldWidth / Float(cols)
        let cellSizeY = worldHeight / Float(rows)
        
        let gap: Float = 0.85
        let quadHalfW = (cellSizeX * gap) / 2.0
        let quadHalfH = (cellSizeY * gap) / 2.0
        
        var vertices: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        var normals: [SCNVector3] = []
        
        var particleVertices: [SCNVector3] = []
        var particleColors: [SCNVector3] = []
        
        let startX = -worldWidth / 2.0
        let baseRadius = min(worldWidth, worldHeight) / 2.0 * 0.95
        var index: Int32 = 0
        
        let pixelDataStart = CFAbsoluteTimeGetCurrent()
        let pixelData = normalizedImage.cgImage?.dataProvider?.data
        let data: UnsafePointer<UInt8>? = CFDataGetBytePtr(pixelData)
        let bytesPerPixel = 4
        let bytesPerRow = normalizedImage.cgImage?.bytesPerRow ?? 0
        let pDensity = self.particleDensity
        print("[ParticleManager] 🔍 Pixel data access: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - pixelDataStart) * 1000))ms, bytesPerRow: \(bytesPerRow)")
        
        let loopStart = CFAbsoluteTimeGetCurrent()
        for r in 0..<rows {
            for c in 0..<cols {
                let cx = startX + (Float(c) + 0.5) * cellSizeX
                let yPos = (worldHeight / 2.0) - (Float(r) + 0.5) * cellSizeY
                
                let dist = sqrt(cx*cx + yPos*yPos)
                let angle = atan2(yPos, cx)
                let noise = (sin(angle * 10.0) + cos(angle * 23.0)) * 0.05 * baseRadius
                let randomNoise = Float.random(in: -0.1...0.1) * baseRadius
                
                if dist > (baseRadius + Float(noise) + randomNoise) {
                    let count = Int(pDensity)
                    let remainder = pDensity - Float(count)
                    var attempts = count
                    if Float.random(in: 0...1) < remainder { attempts += 1 }
                    
                    for _ in 0..<attempts {
                        if Float.random(in: 0...1) > 0.2, let data = data {
                            let u1 = CGFloat(c) / CGFloat(cols)
                            let vRow_top = CGFloat(r) / CGFloat(rows)
                            let ix = Int(u1 * CGFloat(normalizedImage.size.width))
                            let iy = Int(vRow_top * CGFloat(normalizedImage.size.height))
                            
                            if ix >= 0 && ix < Int(normalizedImage.size.width) && iy >= 0 && iy < Int(normalizedImage.size.height) {
                                let pixelIndex = iy * bytesPerRow + ix * bytesPerPixel
                                let red = Float(data[pixelIndex]) / 255.0
                                let green = Float(data[pixelIndex + 1]) / 255.0
                                let blue = Float(data[pixelIndex + 2]) / 255.0
                                let jitterX = Float.random(in: -cellSizeX*0.5...cellSizeX*0.5)
                                let jitterY = Float.random(in: -cellSizeY*0.5...cellSizeY*0.5)
                                particleVertices.append(SCNVector3(cx + jitterX, yPos + jitterY, 0))
                                particleColors.append(SCNVector3(red, green, blue))
                            }
                        }
                    }
                    continue
                }
                
                let v1 = SCNVector3(cx - quadHalfW, yPos + quadHalfH, 0)
                let v2 = SCNVector3(cx + quadHalfW, yPos + quadHalfH, 0)
                let v3 = SCNVector3(cx - quadHalfW, yPos - quadHalfH, 0)
                let v4 = SCNVector3(cx + quadHalfW, yPos - quadHalfH, 0)
                vertices.append(contentsOf: [v1, v2, v3, v4])
                
                let n = SCNVector3(0, 0, 1)
                normals.append(contentsOf: [n, n, n, n])
                
                let u1 = CGFloat(c) / CGFloat(cols)
                let u2 = CGFloat(c+1) / CGFloat(cols)
                let vRow_top = CGFloat(r) / CGFloat(rows)
                let vRow_bottom = CGFloat(r+1) / CGFloat(rows)
                uvs.append(contentsOf: [
                    CGPoint(x: u1, y: vRow_top), CGPoint(x: u2, y: vRow_top),
                    CGPoint(x: u1, y: vRow_bottom), CGPoint(x: u2, y: vRow_bottom)
                ])
                
                indices.append(contentsOf: [index+2, index+1, index, index+2, index+3, index+1])
                index += 4
            }
        }
        
        print("[ParticleManager] 🔍 Grid loop: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - loopStart) * 1000))ms — vertices: \(vertices.count), particles: \(particleVertices.count)")
        
        let geoStart = CFAbsoluteTimeGetCurrent()
        let srcVertices = SCNGeometrySource(vertices: vertices)
        let srcNormals = SCNGeometrySource(normals: normals)
        let srcUVs = SCNGeometrySource(textureCoordinates: uvs)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [srcVertices, srcNormals, srcUVs], elements: [element])
        
        print("[ParticleManager] 🔍 SCNGeometry build: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - geoStart) * 1000))ms")
        
        let matStart = CFAbsoluteTimeGetCurrent()
        let material = SCNMaterial()
        material.diffuse.contents = normalizedImage
        material.isDoubleSided = true
        material.lightingModel = .constant
        
        let shaderModifier = """
        uniform float amplitude;
        uniform float frequency;
        uniform float speed;
        
        float time = u_time;
        vec2 pos = _geometry.position.xy * 0.5 * frequency;
        vec2 anim = vec2(time * speed * 0.2, time * speed * 0.1);
        vec2 p = pos + anim;
        
        float total = 0.0;
        float amp = 1.0;
        float maxVal = 0.0;
        
        vec2 ip = floor(p); vec2 u = fract(p); u = u*u*(3.0-2.0*u);
        float n1 = mix(
            mix(fract(sin(dot(ip, vec2(12.9898,78.233))) * 43758.5453),
                fract(sin(dot(ip+vec2(1.0,0.0), vec2(12.9898,78.233))) * 43758.5453), u.x),
            mix(fract(sin(dot(ip+vec2(0.0,1.0), vec2(12.9898,78.233))) * 43758.5453),
                fract(sin(dot(ip+vec2(1.0,1.0), vec2(12.9898,78.233))) * 43758.5453), u.x), u.y);
        total += n1 * amp; maxVal += amp; amp *= 0.5; p *= 2.0;
        
        ip = floor(p); u = fract(p); u = u*u*(3.0-2.0*u);
        float n2 = mix(
            mix(fract(sin(dot(ip, vec2(12.9898,78.233))) * 43758.5453),
                fract(sin(dot(ip+vec2(1.0,0.0), vec2(12.9898,78.233))) * 43758.5453), u.x),
            mix(fract(sin(dot(ip+vec2(0.0,1.0), vec2(12.9898,78.233))) * 43758.5453),
                fract(sin(dot(ip+vec2(1.0,1.0), vec2(12.9898,78.233))) * 43758.5453), u.x), u.y);
        total += n2 * amp; maxVal += amp; amp *= 0.5; p *= 2.0;
        
        ip = floor(p); u = fract(p); u = u*u*(3.0-2.0*u);
        float n3 = mix(
            mix(fract(sin(dot(ip, vec2(12.9898,78.233))) * 43758.5453),
                fract(sin(dot(ip+vec2(1.0,0.0), vec2(12.9898,78.233))) * 43758.5453), u.x),
            mix(fract(sin(dot(ip+vec2(0.0,1.0), vec2(12.9898,78.233))) * 43758.5453),
                fract(sin(dot(ip+vec2(1.0,1.0), vec2(12.9898,78.233))) * 43758.5453), u.x), u.y);
        total += n3 * amp; maxVal += amp;
        
        float finalNoise = total / maxVal;
        float z = (finalNoise - 0.5) * 2.0 * amplitude * 2.0;
        _geometry.position.z += z;
        """
        
        material.shaderModifiers = [.geometry: shaderModifier]
        let amp = self.waveAmplitude
        let freq = self.waveFrequency
        let spd = self.waveSpeed
        let pSize = Float(self.particleSize)
        material.setValue(amp, forKey: "amplitude")
        material.setValue(freq, forKey: "frequency")
        material.setValue(spd, forKey: "speed")
        geometry.materials = [material]
        print("[ParticleManager] 🔍 Material + Shader setup: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - matStart) * 1000))ms")
        
        let node = SCNNode(geometry: geometry)
        node.eulerAngles = SCNVector3(0, 0, 0)
        
        let particleBuildStart = CFAbsoluteTimeGetCurrent()
        if !particleVertices.isEmpty {
            var quadVertices: [SCNVector3] = []
            var quadColors: [Data] = []
            var quadUVs: [CGPoint] = []
            var quadIndices: [Int32] = []
            var pIndex: Int32 = 0
            
            for i in 0..<particleVertices.count {
                let center = particleVertices[i]
                let color = particleColors[i]
                
                quadVertices.append(contentsOf: [center, center, center, center])
                quadUVs.append(contentsOf: [
                    CGPoint(x: -1, y: 1), CGPoint(x: 1, y: 1),
                    CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1)
                ])
                
                let r = Float(color.x); let g = Float(color.y); let b = Float(color.z); let a = Float(1.0)
                let colorBytes = withUnsafeBytes(of: r) { Data($0) } +
                                 withUnsafeBytes(of: g) { Data($0) } +
                                 withUnsafeBytes(of: b) { Data($0) } +
                                 withUnsafeBytes(of: a) { Data($0) }
                quadColors.append(contentsOf: [colorBytes, colorBytes, colorBytes, colorBytes])
                
                quadIndices.append(contentsOf: [pIndex, pIndex+1, pIndex+2, pIndex+1, pIndex+3, pIndex+2])
                pIndex += 4
            }
            
            let pSrc = SCNGeometrySource(vertices: quadVertices)
            let pUVSrc = SCNGeometrySource(textureCoordinates: quadUVs)
            var fullColorData = Data()
            for d in quadColors { fullColorData.append(d) }
            let colorSource = SCNGeometrySource(data: fullColorData, semantic: .color,
                                                vectorCount: quadVertices.count, usesFloatComponents: true,
                                                componentsPerVector: 4, bytesPerComponent: 4,
                                                dataOffset: 0, dataStride: 16)
            let pElement = SCNGeometryElement(indices: quadIndices, primitiveType: .triangles)
            let pGeo = SCNGeometry(sources: [pSrc, pUVSrc, colorSource], elements: [pElement])
            
            let pMat = SCNMaterial()
            pMat.diffuse.contents = UIColor.white
            pMat.isDoubleSided = true
            pMat.lightingModel = .constant
            pMat.blendMode = .alpha
            pMat.writesToDepthBuffer = false
            
            let pShader = """
            uniform float particleSize;
            vec2 corner = _geometry.texcoords[0];
            float time = u_time;
            vec3 dir = normalize(_geometry.position.xyz);
            float random = fract(sin(dot(_geometry.position.xy, vec2(12.9898, 78.233))) * 43758.5453);
            float speed = 0.2 + random * 0.3;
            float maxDist = 8.0;
            float progress = fract(time * speed * 0.5);
            vec3 centerPos = _geometry.position.xyz + dir * progress * maxDist;
            float scale = 0.01 * particleSize;
            vec3 offset = vec3(corner.x * scale, corner.y * scale, 0.0);
            _geometry.position.xyz = centerPos + offset;
            _geometry.color.a *= (1.0 - progress);
            """
            pMat.shaderModifiers = [.geometry: pShader]
            pMat.setValue(pSize, forKey: "particleSize")
            pGeo.materials = [pMat]
            let pNode = SCNNode(geometry: pGeo)
            node.addChildNode(pNode)
        }
        print("[ParticleManager] 🔍 Particle billboard build: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - particleBuildStart) * 1000))ms")
        
        let bgTotal = CFAbsoluteTimeGetCurrent() - totalStart
        print("[ParticleManager] 🔍 BG work total: \(String(format: "%.0f", bgTotal * 1000))ms — ready to prepare + mount")
        
        if let scnView = self.scnView {
            // 使用 prepare() 在背景线程预编译 Metal Shader + 上传 GPU Buffer
            // 完成后再挂载节点，首帧渲染零成本
            let prepareStart = CFAbsoluteTimeGetCurrent()
            print("[ParticleManager] 🔍 SCNView.prepare() starting (BG shader compile + GPU upload)...")
            scnView.prepare([node]) { [weak self] success in
                let prepareTime = CFAbsoluteTimeGetCurrent() - prepareStart
                print("[ParticleManager] 🔍 SCNView.prepare() done: \(String(format: "%.0f", prepareTime * 1000))ms, success: \(success)")
                
                DispatchQueue.main.async {
                    let mountStart = CFAbsoluteTimeGetCurrent()
                    guard let self = self else { return }
                    self.currentImage = normalizedImage
                    self.gridM = rows
                    self.geometryNode?.removeFromParentNode()
                    self.scene.rootNode.addChildNode(node)
                    self.geometryNode = node
                    print("[ParticleManager] 🔍 Main thread node mount (post-prepare): \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - mountStart) * 1000))ms")
                    print("[ParticleManager] ✅ createMeshInBackground TOTAL: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - totalStart) * 1000))ms")
                }
            }
        } else {
            print("[ParticleManager] ⚠️ scnView is nil, falling back to direct mount (may cause first-frame stutter)")
            DispatchQueue.main.async { [weak self] in
                let mountStart = CFAbsoluteTimeGetCurrent()
                guard let self = self else { return }
                self.currentImage = normalizedImage
                self.gridM = rows
                self.geometryNode?.removeFromParentNode()
                self.scene.rootNode.addChildNode(node)
                self.geometryNode = node
                print("[ParticleManager] 🔍 Main thread node mount (no prepare): \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - mountStart) * 1000))ms")
                print("[ParticleManager] ✅ createMeshInBackground TOTAL: \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - totalStart) * 1000))ms")
            }
        }
    }
}

// MARK: - UIImage 方向归一化

extension UIImage {
    /// 将图片方向归一化为 .up
    /// iPhone 拍摄的 HEIC/JPEG 带 EXIF 方向标记，cgImage 原始像素不旋转
    /// 归一化后 cgImage 像素数据与 size 方向一致
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalized ?? self
    }
}
