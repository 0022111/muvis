import AVFoundation
import AppKit
import RealityKit
import SwiftUI

@main
struct MuVisApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup("muvis") {
            ContentView()
        }
        .defaultSize(width: 1280, height: 760)
    }
}

// MARK: - Data

struct Series {
    var startTime: Double = 0
    var resolution: Double = 1
    var values: [Double] = []

    func sample(at t: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let i = Int((t - startTime) / resolution)
        return values[max(0, min(values.count - 1, i))]
    }

    init() {}

    init?(json: Any?) {
        guard let d = json as? [String: Any],
              let values = d["values"] as? [Double],
              let resolution = d["resolution"] as? Double else { return nil }
        self.startTime = d["startTime"] as? Double ?? 0
        self.resolution = resolution
        self.values = values
    }
}

struct SongSection {
    let start: Double
    let end: Double
    let label: String
    let hype: Int
}

struct Word {
    let start: Double
    let end: Double
    let text: String
}

// MARK: - Model

@Observable @MainActor
final class VisModel {
    let player = AVPlayer()
    var loaded = false
    var trackName = "drop an audio file (with its .mudump.json sibling)"
    var duration: Double = 1

    var bass = Series()
    var drum = Series()
    var vocal = Series()
    var pace = Series()
    var sections: [SongSection] = []
    var boundaries: [Double] = []
    var words: [Word] = []

    // Tweakables — live, all of them.
    var symmetry: Double = 6
    var bassGain: Double = 1.0
    var drumGain: Double = 1.0
    var ringCount: Double = 10
    var hueShift: Double = 0
    var spin: Double = 1.0
    var showLyrics = true
    var lyricSize: Double = 1.0
    var isPlaying = false

    // Scene plumbing.
    var root = Entity()
    var center = ModelEntity()
    var ring: [ModelEntity] = []
    var outer: [ModelEntity] = []
    private var angle: Float = 0
    private var lastTick: Date?

    static let maxRing = 16
    static let labelHue: [String: Double] = [
        "intro": 0.58, "verse": 0.50, "buildup": 0.10, "drop": 0.98,
        "breakdown": 0.45, "bridge": 0.75, "outro": 0.62,
    ]

    var time: Double {
        let t = player.currentTime().seconds
        return t.isFinite ? t : 0
    }

    func currentSection(at t: Double) -> SongSection? {
        sections.first { t >= $0.start && t < $0.end }
    }

    /// Exponentially decaying pulse from the most recent section boundary.
    func boundaryPulse(at t: Double) -> Double {
        guard let last = boundaries.last(where: { $0 <= t }) else { return 0 }
        return exp(-(t - last) * 3.0)
    }

    func activeWords(at t: Double) -> String {
        words.filter { $0.start <= t && t <= $0.end + 0.45 }
            .map(\.text).joined(separator: " ")
    }

    func load(url: URL) {
        let audioExtensions = ["aif", "aiff", "wav", "mp3", "m4a", "flac", "caf", "aac"]
        var audioURL = url
        var jsonURL = url.deletingPathExtension().appendingPathExtension("mudump.json")
        if url.pathExtension == "json" {
            jsonURL = url
            let base = url.deletingPathExtension().deletingPathExtension()
            guard let found = audioExtensions
                .map({ base.appendingPathExtension($0) })
                .first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return }
            audioURL = found
        }
        guard let data = try? Data(contentsOf: jsonURL),
              let dump = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            trackName = "no .mudump.json next to \(url.lastPathComponent) — run mudump first"
            return
        }

        let activity = (dump["instrumentActivity"] as? [String: Any])?["activity"] as? [String: Any]
        bass = Series(json: activity?["bass"]) ?? Series()
        drum = Series(json: activity?["drum"]) ?? Series()
        vocal = Series(json: activity?["vocal"]) ?? Series()

        if let dp = dump["decodedPredictions"] as? [String: Any],
           let pc = dp["paceCurve"] as? [String: Any],
           var s = Series(json: ["values": pc["expectedBin"] ?? [], "resolution": pc["resolution"] ?? 0.05]) {
            // Normalize expected-bin (roughly 8–25) to 0–1.
            s.values = s.values.map { min(1, max(0, ($0 - 8) / 17)) }
            pace = s
        }

        sections = ((dump["structure"] as? [String: Any])?["sections"] as? [[String: Any]] ?? [])
            .compactMap { s in
                guard let start = s["start"] as? Double, let end = s["end"] as? Double else { return nil }
                return SongSection(start: start, end: end,
                                   label: s["label"] as? String ?? "",
                                   hype: s["hype"] as? Int ?? 5)
            }

        if let dp = dump["decodedPredictions"] as? [String: Any],
           let level = dp["sections"] as? [String: Any],
           let peaks = level["boundaryPeaks"] as? [[String: Double]] {
            boundaries = peaks.compactMap { $0["time"] }.sorted()
        } else {
            boundaries = sections.map(\.start)
        }

        words = (dump["transcript"] as? [[String: Any]] ?? []).compactMap { w in
            guard let start = w["start"] as? Double,
                  let end = w["end"] as? Double,
                  let text = w["text"] as? String else { return nil }
            return Word(start: start, end: end, text: text)
        }

        let item = AVPlayerItem(url: audioURL)
        player.replaceCurrentItem(with: item)
        trackName = audioURL.deletingPathExtension().lastPathComponent
        Task {
            if let d = try? await item.asset.load(.duration).seconds, d.isFinite { duration = d }
        }
        loaded = true
        play()
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to t: Double) {
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: Scene

    func buildScene(_ content: inout some RealityViewContentProtocol) {
        let camera = PerspectiveCamera()
        camera.position = [0, 0, 4.2]
        content.add(camera)

        center = ModelEntity(mesh: .generateSphere(radius: 0.34),
                             materials: [UnlitMaterial(color: .white)])
        root.addChild(center)

        ring = (0..<Self.maxRing).map { _ in
            let e = ModelEntity(mesh: .generateBox(size: 0.22, cornerRadius: 0.04),
                                materials: [UnlitMaterial(color: .white)])
            root.addChild(e)
            return e
        }
        outer = (0..<Self.maxRing).map { _ in
            let e = ModelEntity(mesh: .generateSphere(radius: 0.06),
                                materials: [UnlitMaterial(color: .white)])
            root.addChild(e)
            return e
        }
        content.add(root)
    }

    /// Per-frame scene update, driven by RealityKit's update event.
    func tick() {
        let now = Date()
        let dt = Float(min(0.1, now.timeIntervalSince(lastTick ?? now)))
        lastTick = now

        let t = time
        let bassV = min(1.5, bass.sample(at: t) * bassGain)
        let drumV = min(1.5, drum.sample(at: t) * drumGain)
        let paceV = pace.sample(at: t)
        let pulse = boundaryPulse(at: t)
        let section = currentSection(at: t)
        let baseHue = (Self.labelHue[section?.label ?? ""] ?? 0.6) + hueShift
        let hype = Double(section?.hype ?? 5) / 10

        angle += dt * Float(spin) * (0.25 + Float(paceV) * 2.2)
        root.orientation = simd_quatf(angle: angle * 0.25, axis: [0, 0, 1])

        center.scale = .one * Float(0.65 + bassV * 0.85 + pulse * 0.3)
        center.model?.materials = [UnlitMaterial(color: color(hue: baseHue, brightness: 0.55 + bassV * 0.45))]

        let n = max(2, Int(ringCount))
        let radius = Float(1.25 + pulse * 0.55 + bassV * 0.12)
        for (k, e) in ring.enumerated() {
            guard k < n else { e.isEnabled = false; continue }
            e.isEnabled = true
            let a = Float(k) / Float(n) * .pi * 2 + angle
            e.position = [cos(a) * radius, sin(a) * radius, 0]
            e.orientation = simd_quatf(angle: a + angle * 2, axis: [0, 0, 1])
            e.scale = .one * Float(0.55 + drumV * 0.9)
            e.model?.materials = [UnlitMaterial(color: color(hue: baseHue + 0.08, brightness: 0.35 + drumV * 0.65))]
        }
        let outerRadius = radius + 0.65 + Float(drumV) * 0.25
        for (k, e) in outer.enumerated() {
            guard k < n else { e.isEnabled = false; continue }
            e.isEnabled = true
            let a = Float(k) / Float(n) * .pi * 2 - angle * 1.6
            e.position = [cos(a) * outerRadius, sin(a) * outerRadius, -0.3]
            e.scale = .one * Float(0.5 + paceV * 1.2 + hype * 0.5)
            e.model?.materials = [UnlitMaterial(color: color(hue: baseHue - 0.1, brightness: 0.3 + paceV * 0.7))]
        }
    }

    private func color(hue: Double, brightness: Double) -> NSColor {
        NSColor(hue: hue.truncatingRemainder(dividingBy: 1),
                saturation: 0.85,
                brightness: min(1, brightness),
                alpha: 1)
    }
}

// MARK: - Views

struct ContentView: View {
    @State private var model = VisModel()
    @State private var showControls = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = model.time
            let _ = timeline.date
            ZStack(alignment: .trailing) {
                visual(t: t)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showControls {
                    ControlPanel(model: model, t: t, showControls: $showControls,
                                 openFile: openFile)
                        .frame(width: 260)
                        .background(.black.opacity(0.65))
                } else {
                    Button("Controls") { showControls = true }
                        .padding(8)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .background(.black)
        .dropDestination(for: URL.self) { urls, _ in
            if let url = urls.first { model.load(url: url) }
            return true
        }
        .onAppear {
            if let path = CommandLine.arguments.dropFirst().first {
                model.load(url: URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
            }
        }
    }

    func visual(t: Double) -> some View {
        ZStack {
            RealityView { content in
                var content = content
                model.buildScene(&content)
                _ = content.subscribe(to: SceneEvents.Update.self) { _ in
                    Task { @MainActor in model.tick() }
                }
            }
            .background(.black)

            if model.showLyrics {
                let line = model.activeWords(at: t)
                if !line.isEmpty {
                    Text(line)
                        .font(.system(size: 40 * model.lyricSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .scaleEffect(1 + model.vocal.sample(at: t) * 0.15)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 60)
                }
            }

            if !model.loaded {
                Text(model.trackName)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .json]
        if panel.runModal() == .OK, let url = panel.url {
            model.load(url: url)
        }
    }
}

struct ControlPanel: View {
    @Bindable var model: VisModel
    let t: Double
    @Binding var showControls: Bool
    var openFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Open…", action: openFile)
                Button(model.isPlaying ? "Pause" : "Play") {
                    model.isPlaying ? model.pause() : model.play()
                }
                .disabled(!model.loaded)
                Spacer()
                Button("Hide") { showControls = false }
            }
            Text(model.trackName).font(.headline).lineLimit(2)

            if let s = model.currentSection(at: t) {
                Text("\(s.label.isEmpty ? "section" : s.label)  ·  hype \(s.hype)/10")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            Slider(value: Binding(
                get: { t },
                set: { model.seek(to: $0) }
            ), in: 0...max(1, model.duration)) {
                Text(String(format: "%d:%02d", Int(t) / 60, Int(t) % 60))
                    .font(.caption.monospacedDigit())
            }

            Divider()
            slider("Symmetry", $model.symmetry, 0...12, step: 1)
            slider("Bass gain", $model.bassGain, 0...3)
            slider("Drum gain", $model.drumGain, 0...3)
            slider("Shapes", $model.ringCount, 2...Double(VisModel.maxRing), step: 1)
            slider("Hue shift", $model.hueShift, 0...1)
            slider("Spin", $model.spin, 0...3)
            Divider()
            Toggle("Lyrics", isOn: $model.showLyrics)
            slider("Lyric size", $model.lyricSize, 0.5...2)
            Spacer()
        }
        .padding()
    }

    func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                step: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label): \(value.wrappedValue, specifier: "%.2f")").font(.caption)
            if let step {
                Slider(value: value, in: range, step: step)
            } else {
                Slider(value: value, in: range)
            }
        }
    }
}
