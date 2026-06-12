import AppKit
import MetalKit
import SwiftUI
import simd

// MARK: - GPU-shared types (lane maps must match Shaders.metal)

struct VisUniforms {
    var viewProj = matrix_identity_float4x4
    var audio = SIMD4<Float>(repeating: 0)   // bass, drum, vocal, pace
    var pulse = SIMD4<Float>(repeating: 0)   // boundary pulse, hype, hue, wall time
    var morph = SIMD4<Float>(repeating: 0)   // shape from, shape to, mix, spin angle
    var params = SIMD4<Float>(repeating: 0)  // dt, point scale, energy, aspect
    var post = SIMD4<Float>(repeating: 0)    // kaleido segments, trail decay, feedback zoom, feedback twist
    var post2 = SIMD4<Float>(repeating: 0)   // exposure, vignette, aberration, brightness scale
    var rhythm = SIMD4<Float>(repeating: 0)  // beat pulse, bar pulse, beat phase, bpm norm
    var energy = SIMD4<Float>(repeating: 0)  // loudness, punch, phrase pulse, EDR headroom
    var extra = SIMD4<Float>(repeating: 0)   // shape scale, shape hue offset, shape brightness, minor-key flag
}

struct VisParticle {
    var posLife: SIMD4<Float>
    var velSeed: SIMD4<Float>
}

// MARK: - SwiftUI bridge

struct MetalVisualView: NSViewRepresentable {
    let model: VisModel

    func makeCoordinator() -> Renderer { Renderer(model: model) }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        // True EDR output: float drawable in extended linear Display P3, so
        // highlights can exceed 1.0 and light up XDR panels past UI white.
        view.colorPixelFormat = .rgba16Float
        view.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        (view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = 120
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}

// MARK: - Renderer

@MainActor
final class Renderer: NSObject, @preconcurrency MTKViewDelegate {
    static let maxParticles = 200_000
    static let shapeVertices = 2048  // keep in sync with kShapeVertices in Shaders.metal
    static let labelShape: [String: Float] = [
        "intro": 0, "verse": 4, "buildup": 3, "drop": 1,
        "breakdown": 2, "bridge": 5, "outro": 0,
    ]

    let device: MTLDevice
    private let model: VisModel
    private let queue: MTLCommandQueue
    private let simulate: MTLComputePipelineState
    private let feedback: MTLRenderPipelineState
    private let shape: MTLRenderPipelineState
    private let points: MTLRenderPipelineState
    private let post: MTLRenderPipelineState
    private let particles: MTLBuffer

    private var accum: [MTLTexture] = []
    private var front = 0
    private var accumNeedsClear = true

    private let start = Date()
    private var lastFrame: Date?
    private var spinAngle: Float = 0
    private var smoothBass: Float = 0
    private var kickEnv: Float = 0
    private var lastDrum: Float = 0
    private var currentLabel: String?
    private var shapeFrom: Float = 0
    private var shapeTo: Float = 0
    private var morphStart: Float = 0
    private var haloExtra = SIMD4<Float>(1.5, 0.38, 0.3, 0)

    init(model: VisModel) {
        self.model = model
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("muvis needs a Metal GPU")
        }
        self.device = device
        self.queue = queue

        do {
            let library = try device.makeDefaultLibrary(bundle: .module)

            func render(_ vertex: String, _ fragment: String,
                        format: MTLPixelFormat, additive: Bool) throws -> MTLRenderPipelineState {
                let d = MTLRenderPipelineDescriptor()
                d.vertexFunction = library.makeFunction(name: vertex)
                d.fragmentFunction = library.makeFunction(name: fragment)
                let att = d.colorAttachments[0]!
                att.pixelFormat = format
                if additive {
                    att.isBlendingEnabled = true
                    att.rgbBlendOperation = .add
                    att.alphaBlendOperation = .add
                    att.sourceRGBBlendFactor = .one
                    att.destinationRGBBlendFactor = .one
                    att.sourceAlphaBlendFactor = .one
                    att.destinationAlphaBlendFactor = .one
                }
                return try device.makeRenderPipelineState(descriptor: d)
            }

            guard let sim = library.makeFunction(name: "simulate") else {
                fatalError("missing simulate kernel")
            }
            simulate = try device.makeComputePipelineState(function: sim)
            feedback = try render("screenVert", "feedbackFrag", format: .rgba16Float, additive: false)
            shape = try render("shapeVert", "lineFrag", format: .rgba16Float, additive: true)
            points = try render("particleVert", "particleFrag", format: .rgba16Float, additive: true)
            post = try render("screenVert", "postFrag", format: .rgba16Float, additive: false)
        } catch {
            fatalError("muvis pipeline setup failed: \(error)")
        }

        let initial = (0..<Self.maxParticles).map { _ in
            VisParticle(
                posLife: SIMD4(Float.random(in: -1.6...1.6),
                               Float.random(in: -1.6...1.6),
                               Float.random(in: -1.6...1.6),
                               Float.random(in: 0...1)),
                velSeed: SIMD4(0, 0, 0, Float.random(in: 0...1)))
        }
        guard let buffer = device.makeBuffer(
            bytes: initial,
            length: MemoryLayout<VisParticle>.stride * initial.count,
            options: .storageModeShared) else {
            fatalError("muvis particle buffer allocation failed")
        }
        particles = buffer
        super.init()
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        accum = []
    }

    func draw(in view: MTKView) {
        let size = view.drawableSize
        guard size.width > 1, size.height > 1 else { return }
        if accum.count != 2 || accum[0].width != Int(size.width) || accum[0].height != Int(size.height) {
            rebuildTextures(size: size)
        }
        guard accum.count == 2,
              let drawable = view.currentDrawable,
              let drawableRPD = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer() else { return }

        let headroom = Float(view.window?.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1)
        var u = makeUniforms(aspect: Float(size.width / size.height),
                             pointScale: Float(size.height) / 540,
                             headroom: max(1, headroom))
        let uniformLength = MemoryLayout<VisUniforms>.stride

        if accumNeedsClear {
            for texture in accum { clear(texture, with: cmd) }
            accumNeedsClear = false
        }

        let active = max(1, min(Self.maxParticles, Int(model.particles)))
        if let enc = cmd.makeComputeCommandEncoder() {
            enc.setComputePipelineState(simulate)
            enc.setBuffer(particles, offset: 0, index: 0)
            enc.setBytes(&u, length: uniformLength, index: 1)
            let width = min(256, simulate.maxTotalThreadsPerThreadgroup)
            enc.dispatchThreads(MTLSize(width: active, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1))
            enc.endEncoding()
        }

        // Trail pass: decayed feedback of last frame, then the scene on top.
        let trailRPD = MTLRenderPassDescriptor()
        trailRPD.colorAttachments[0].texture = accum[front]
        trailRPD.colorAttachments[0].loadAction = .dontCare
        trailRPD.colorAttachments[0].storeAction = .store
        if let enc = cmd.makeRenderCommandEncoder(descriptor: trailRPD) {
            enc.setRenderPipelineState(feedback)
            enc.setFragmentTexture(accum[1 - front], index: 0)
            enc.setFragmentBytes(&u, length: uniformLength, index: 1)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

            enc.setRenderPipelineState(shape)
            enc.setVertexBytes(&u, length: uniformLength, index: 1)
            enc.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: Self.shapeVertices)

            // Halo: the same curve expanded and recolored, riding the "other"
            // (melodic/harmonic) stem.
            var halo = u
            halo.extra = haloExtra
            enc.setVertexBytes(&halo, length: uniformLength, index: 1)
            enc.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: Self.shapeVertices)

            enc.setRenderPipelineState(points)
            enc.setVertexBuffer(particles, offset: 0, index: 0)
            enc.setVertexBytes(&u, length: uniformLength, index: 1)
            enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: active)
            enc.endEncoding()
        }

        // Post pass: composite the trail buffer to the drawable.
        if let enc = cmd.makeRenderCommandEncoder(descriptor: drawableRPD) {
            enc.setRenderPipelineState(post)
            enc.setFragmentTexture(accum[front], index: 0)
            enc.setFragmentBytes(&u, length: uniformLength, index: 1)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
        }

        cmd.present(drawable)
        cmd.commit()
        front = 1 - front
    }

    // MARK: Frame state

    private func makeUniforms(aspect: Float, pointScale: Float, headroom: Float) -> VisUniforms {
        let now = Date()
        let dt = Float(now.timeIntervalSince(lastFrame ?? now.addingTimeInterval(-1.0 / 120)))
            .clamped(to: 0...(1.0 / 24))
        lastFrame = now
        let wall = Float(now.timeIntervalSince(start))
        let t = model.time

        let bassRaw = Float(min(1.5, model.bass.sample(at: t) * model.bassGain))
        smoothBass += (bassRaw - smoothBass) * min(1, dt * 9)
        let drumRaw = Float(min(1.5, model.drum.sample(at: t) * model.drumGain))
        kickEnv = max(kickEnv * exp(-dt * 5.5), min(1, max(0, drumRaw - lastDrum) * 6))
        lastDrum = drumRaw
        let drum = min(1.5, drumRaw * 0.8 + kickEnv * 0.6)
        let vocal = Float(min(1.5, model.vocal.sample(at: t)))
        let other = Float(min(1.5, model.other.sample(at: t)))
        let pace = Float(model.pace.sample(at: t))
        let pulse = Float(model.boundaryPulse(at: t))
        let section = model.currentSection(at: t)
        let hype = Float(section?.hype ?? 5) / 10

        // Rhythm clocks: decaying envelopes from the last beat and bar.
        var beatPulse: Float = 0, barPulse: Float = 0, beatPhase: Float = 0
        if let (last, next) = model.neighbors(in: model.beats, at: t) {
            beatPulse = Float(exp(-(t - last) * 9))
            beatPhase = Float(min(1, max(0, (t - last) / max(0.05, next - last))))
        }
        if let (last, _) = model.neighbors(in: model.bars, at: t) {
            barPulse = Float(exp(-(t - last) * 5))
        }
        let bpmNorm = Float(min(1.5, model.bpm / 140))

        // Loudness relative to the song's integrated LUFS gates the whole
        // scene's energy; momentary minus short-term is the transient punch.
        let hasLoudness = !model.loudMomentary.values.isEmpty
        let momentary = model.loudMomentary.sample(at: t)
        let loud: Float = hasLoudness
            ? Float(max(0, min(1.25, (momentary - model.integratedLUFS + 10) / 14)))
            : 0.8
        let punch: Float = hasLoudness && !model.loudShortTerm.values.isEmpty
            ? Float(max(0, min(1, (momentary - model.loudShortTerm.sample(at: t)) / 5)))
            : 0

        // Finer structure levels shimmer; sections stay the big detonations.
        let phrasePulse = Float(model.peakPulse(model.phrasePeaks, at: t, rate: 7) * 0.6
                              + model.peakPulse(model.segmentPeaks, at: t, rate: 5))

        // Palette: the song's key, mapped around the circle of fifths, is the
        // base hue; section labels offset around it; minor keys flag moodier.
        let key = model.currentKey(at: t)
        let sectionOffset = ((VisModel.labelHue[section?.label ?? ""] ?? 0.6) - 0.5) * 0.35
        let hue = Float((key?.hue ?? 0.61) + sectionOffset + model.hueShift)
        let minorFlag: Float = key?.minor == true ? 1 : 0

        // Morph the hero shape on section changes; idle-cycle when no song.
        let label = (section?.label).flatMap { $0.isEmpty ? nil : $0 } ?? "auto\(Int(wall / 12) % 6)"
        if label != currentLabel {
            currentLabel = label
            shapeFrom = shapeTo
            if let s = Self.labelShape[label] {
                shapeTo = s
            } else if label.hasPrefix("auto"), let n = Int(label.dropFirst(4)) {
                shapeTo = Float(n)
            } else {
                shapeTo = Float(label.hashValue.magnitude % 6)
            }
            morphStart = wall
        }
        let morphMix = min(1, (wall - morphStart) / 1.6)

        spinAngle += dt * Float(model.spin) * (0.25 + pace * 1.6 + bpmNorm * 0.6)

        // Orbiting camera: hype pulls in, bars dolly-kick, transients shake.
        let az = spinAngle * 0.3 + wall * 0.02
        let el = 0.35 + sin(wall * 0.11) * 0.35
        let dist = max(2.6, 5.0 - hype * 1.3 - smoothBass * 0.3 - barPulse * 0.18)
        var eye = SIMD3<Float>(cos(az) * cos(el), sin(el), sin(az) * cos(el)) * dist
        eye += SIMD3(sin(wall * 53), sin(wall * 47), sin(wall * 61)) * punch * 0.04
        let viewMatrix = lookAt(eye: eye, center: .zero, up: [0, 1, 0])
        let projMatrix = perspective(fovY: .pi / 3, aspect: aspect, near: 0.05, far: 100)

        var u = VisUniforms()
        u.viewProj = projMatrix * viewMatrix
        u.audio = SIMD4(smoothBass, drum, vocal, pace)
        u.pulse = SIMD4(pulse, hype, hue, wall)
        u.morph = SIMD4(shapeFrom, shapeTo, morphMix, spinAngle)
        u.params = SIMD4(dt, pointScale, 0.7 + hype * 1.6, aspect)
        u.post = SIMD4(Float(model.symmetry),
                       Float(model.trail),
                       1.0 - Float(model.flow) * (0.006 + smoothBass * 0.012)
                           - pulse * 0.008 - barPulse * 0.004,
                       dt * (Float(model.spin) * (0.05 + pace * 0.25) + barPulse * 0.5))
        // Brightness scale normalizes the trail buffer's steady-state gain so
        // longer trails don't blow out: gain ≈ 1 / (1 - decay).
        u.post2 = SIMD4(Float(model.glow), 0.6, 1.0, Float((1 - model.trail) * 10))
        u.rhythm = SIMD4(beatPulse, barPulse, beatPhase, bpmNorm)
        u.energy = SIMD4(loud, punch, phrasePulse, headroom)
        u.extra = SIMD4(1, 0, 1, minorFlag)
        haloExtra = SIMD4(1.5 + other * 0.6, 0.38, 0.30 + other * 0.7, minorFlag)
        return u
    }

    // MARK: Textures

    private func rebuildTextures(size: CGSize) {
        let d = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(size.width), height: Int(size.height),
            mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        accum = [device.makeTexture(descriptor: d), device.makeTexture(descriptor: d)].compactMap { $0 }
        accumNeedsClear = true
    }

    private func clear(_ texture: MTLTexture, with cmd: MTLCommandBuffer) {
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = texture
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        rpd.colorAttachments[0].storeAction = .store
        cmd.makeRenderCommandEncoder(descriptor: rpd)?.endEncoding()
    }
}

// MARK: - Math

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}

private func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tan(fovY * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(columns: (
        SIMD4(x, 0, 0, 0),
        SIMD4(0, y, 0, 0),
        SIMD4(0, 0, z, -1),
        SIMD4(0, 0, z * near, 0)))
}

private func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    return simd_float4x4(columns: (
        SIMD4(x.x, y.x, z.x, 0),
        SIMD4(x.y, y.y, z.y, 0),
        SIMD4(x.z, y.z, z.z, 0),
        SIMD4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)))
}
