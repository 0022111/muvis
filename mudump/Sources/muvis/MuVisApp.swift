import AVFoundation
import AppKit
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

struct KeyRange {
    let start: Double
    let end: Double
    let hue: Double
    let minor: Bool
    let name: String
}

struct Peak {
    let time: Double
    let probability: Double
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
    var other = Series()
    var pace = Series()
    var loudMomentary = Series()
    var loudShortTerm = Series()
    var integratedLUFS: Double = -14
    var beats: [Double] = []
    var bars: [Double] = []
    var bpm: Double = 0
    var keys: [KeyRange] = []
    var sections: [SongSection] = []
    var boundaries: [Double] = []
    var segmentPeaks: [Peak] = []
    var phrasePeaks: [Peak] = []
    var words: [Word] = []

    // Tweakables — live, all of them.
    var symmetry: Double = 0
    var bassGain: Double = 1.0
    var drumGain: Double = 1.0
    var particles: Double = 90_000
    var trail: Double = 0.90
    var glow: Double = 1.3
    var flow: Double = 0.5
    var hueShift: Double = 0
    var spin: Double = 1.0
    var showLyrics = true
    var lyricSize: Double = 1.0
    var isPlaying = false

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

    func currentKey(at t: Double) -> KeyRange? {
        keys.first { t >= $0.start && t < $0.end } ?? keys.last
    }

    /// Most recent event at or before `t`, plus its successor (binary search).
    func neighbors(in events: [Double], at t: Double) -> (last: Double, next: Double)? {
        guard let first = events.first, t >= first else { return nil }
        var lo = 0, hi = events.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if events[mid] <= t { lo = mid } else { hi = mid - 1 }
        }
        let next = lo + 1 < events.count ? events[lo + 1] : events[lo] + 60 / max(bpm, 30)
        return (events[lo], next)
    }

    /// Exponentially decaying pulse from the most recent boundary peak,
    /// scaled by the model's confidence in that boundary.
    func peakPulse(_ peaks: [Peak], at t: Double, rate: Double) -> Double {
        guard let p = peaks.last(where: { $0.time <= t }) else { return 0 }
        return p.probability * exp(-(t - p.time) * rate)
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
        other = Series(json: activity?["other"]) ?? Series()

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

        let dp = dump["decodedPredictions"] as? [String: Any]
        segmentPeaks = Self.parsePeaks(dp?["segments"])
        phrasePeaks = Self.parsePeaks(dp?["phrases"])
        if phrasePeaks.isEmpty,
           let phrases = (dump["structure"] as? [String: Any])?["phrases"] as? [[String: Any]] {
            phrasePeaks = phrases.compactMap { p in
                (p["start"] as? Double).map { Peak(time: $0, probability: 0.5) }
            }
        }

        if let rhythm = dump["rhythm"] as? [String: Any] {
            beats = (rhythm["beats"] as? [Double]) ?? []
            bars = (rhythm["bars"] as? [Double]) ?? []
            bpm = (rhythm["beatsPerMinute"] as? NSNumber)?.doubleValue ?? 0
        }

        if let loud = dump["loudness"] as? [String: Any] {
            loudMomentary = Series(json: loud["momentary"]) ?? Series()
            loudShortTerm = Series(json: loud["shortTerm"]) ?? Series()
            integratedLUFS = (loud["integratedLUFS"] as? NSNumber)?.doubleValue ?? -14
        }

        keys = (dump["key"] as? [[String: Any]] ?? []).compactMap { k in
            guard let start = k["start"] as? Double,
                  let end = k["end"] as? Double,
                  let tonic = k["tonic"] as? String,
                  let pc = Self.pitchClass(tonic) else { return nil }
            let minor = (k["mode"] as? String) == "minor"
            // Circle of fifths laid around the color wheel: related keys get
            // related hues, so a key change is a palette modulation.
            let hue = Double((pc * 7) % 12) / 12
            return KeyRange(start: start, end: end, hue: hue, minor: minor,
                            name: Self.tonicName(tonic) + (minor ? " minor" : " major"))
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

    // MARK: Dump parsing helpers

    private static func parsePeaks(_ any: Any?) -> [Peak] {
        (((any as? [String: Any])?["boundaryPeaks"] as? [[String: Double]]) ?? [])
            .compactMap { p in
                p["time"].map { Peak(time: $0, probability: p["probability"] ?? 1) }
            }
    }

    /// Pitch class for a KeyResult.Tonic raw value ("d", "aFlat", "cSharp", …).
    private static func pitchClass(_ tonic: String) -> Int? {
        var name = tonic.lowercased()
            .replacingOccurrences(of: "♭", with: "flat")
            .replacingOccurrences(of: "♯", with: "sharp")
            .replacingOccurrences(of: "#", with: "sharp")
        if name.count == 2, name.hasSuffix("b") { name = String(name.first!) + "flat" }
        let map: [String: Int] = [
            "c": 0, "csharp": 1, "dflat": 1, "d": 2, "dsharp": 3, "eflat": 3,
            "e": 4, "f": 5, "fsharp": 6, "gflat": 6, "g": 7, "gsharp": 8,
            "aflat": 8, "a": 9, "asharp": 10, "bflat": 10, "b": 11,
        ]
        return map[name]
    }

    private static func tonicName(_ tonic: String) -> String {
        var name = tonic
        guard let letter = name.first else { return tonic }
        name = String(letter).uppercased() + name.dropFirst()
        return name
            .replacingOccurrences(of: "Flat", with: "♭")
            .replacingOccurrences(of: "Sharp", with: "♯")
            .replacingOccurrences(of: "flat", with: "♭")
            .replacingOccurrences(of: "sharp", with: "♯")
            .replacingOccurrences(of: "#", with: "♯")
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
            MetalVisualView(model: model)
                .background(.black)

            if model.showLyrics {
                let line = model.activeWords(at: t)
                if !line.isEmpty {
                    Text(line)
                        .font(.system(size: 40 * model.lyricSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.8), radius: 3)
                        .shadow(color: .cyan.opacity(0.6), radius: 22)
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
            let info = [
                model.currentKey(at: t)?.name,
                model.bpm > 0 ? "\(Int(model.bpm.rounded())) BPM" : nil,
            ].compactMap { $0 }.joined(separator: "  ·  ")
            if !info.isEmpty {
                Text(info).font(.caption).foregroundStyle(.secondary)
            }

            Slider(value: Binding(
                get: { t },
                set: { model.seek(to: $0) }
            ), in: 0...max(1, model.duration)) {
                Text(String(format: "%d:%02d", Int(t) / 60, Int(t) % 60))
                    .font(.caption.monospacedDigit())
            }

            Divider()
            slider("Symmetry", $model.symmetry, 0...12, step: 1, spec: "%.0f")
            slider("Bass gain", $model.bassGain, 0...3)
            slider("Drum gain", $model.drumGain, 0...3)
            slider("Particles", $model.particles, 10_000...200_000, step: 10_000, spec: "%.0f")
            slider("Trails", $model.trail, 0.80...0.99)
            slider("Glow", $model.glow, 0.4...3)
            slider("Flow", $model.flow, 0...1)
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
                step: Double? = nil, spec: String = "%.2f") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label): \(String(format: spec, value.wrappedValue))").font(.caption)
            if let step {
                Slider(value: value, in: range, step: step)
            } else {
                Slider(value: value, in: range)
            }
        }
    }
}
