import AVFoundation
import Foundation
import MusicUnderstanding
import Speech

@main
struct MUDump {

    static func main() async {
        var threshold: Float = 0.10
        var files: [String] = []
        let args = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < args.count {
            if args[i] == "--threshold", i + 1 < args.count {
                threshold = Float(args[i + 1]) ?? threshold
                i += 2
            } else {
                files.append(args[i])
                i += 1
            }
        }
        guard !files.isEmpty else {
            fputs("usage: mudump [--threshold 0.10] <audiofile> ...\n", stderr)
            exit(64)
        }
        for path in files {
            do {
                try await dump(path: path, threshold: threshold)
            } catch {
                fputs("error: \(path): \(error)\n", stderr)
                exit(1)
            }
        }
    }

    static func dump(path: String, threshold: Float) async throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard try await !asset.load(.hasProtectedContent) else {
            throw NSError(domain: "mudump", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "asset is DRM-protected"])
        }

        fputs("analyzing \(url.lastPathComponent)...\n", stderr)
        let started = Date()
        let session = try await MusicUnderstandingSession(asset: asset)
        let result = try await session.analyze()
        fputs(String(format: "analysis took %.1fs\n", Date().timeIntervalSince(started)), stderr)

        // Round-trip through Codable to reach internal fields (structurePredictions)
        // that have no public accessors.
        let raw = try JSONEncoder().encode(result)
        guard let dict = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            throw NSError(domain: "mudump", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "unexpected SessionResult encoding"])
        }

        var out: [String: Any] = [
            "source": url.lastPathComponent,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "boundaryThreshold": threshold,
        ]

        if let rhythm = dict["rhythm"] as? [String: Any] {
            var r: [String: Any] = [:]
            r["beatsPerMinute"] = rhythm["beatsPerMinute"]
            r["beats"] = (rhythm["beats"] as? [Any])?.compactMap(seconds)
            r["bars"] = (rhythm["bars"] as? [Any])?.compactMap(seconds)
            out["rhythm"] = r
        }

        if let key = dict["key"] as? [String: Any], let ranges = key["ranges"] as? [Any] {
            out["key"] = ranges.compactMap { item -> [String: Any]? in
                guard let d = item as? [String: Any],
                      let range = rangeSeconds(d["range"]),
                      let value = d["value"] as? [String: Any] else { return nil }
                return range.merging(["tonic": value["tonic"] ?? "?",
                                      "mode": value["mode"] ?? "?"]) { a, _ in a }
            }
        }

        if let structure = dict["structure"] as? [String: Any] {
            var s: [String: Any] = [:]
            for level in ["sections", "segments", "phrases"] {
                s[level] = (structure[level] as? [Any])?.compactMap(rangeSeconds)
            }
            out["structure"] = s
        }

        if let pace = dict["pace"] as? [String: Any], let ranges = pace["ranges"] as? [Any] {
            out["pacePublic"] = ranges.compactMap { item -> [String: Any]? in
                guard let d = item as? [String: Any],
                      let range = rangeSeconds(d["range"]),
                      let v = (d["value"] as? NSNumber)?.doubleValue else { return nil }
                return range.merging(["eventsPerMinute": v]) { a, _ in a }
            }
        }

        if let loudness = dict["loudness"] as? [String: Any] {
            var l: [String: Any] = [:]
            if let integrated = loudness["integrated"] as? [String: Any] {
                l["integratedLUFS"] = integrated["value"]
            }
            if let peak = loudness["peak"] as? [String: Any] {
                l["peak"] = ["time": seconds(peak["time"]) ?? -1, "value": peak["value"] ?? 0]
            }
            for series in ["momentary", "shortTerm"] {
                guard let points = loudness[series] as? [Any], points.count > 1 else { continue }
                let times = points.compactMap { ($0 as? [String: Any]).flatMap { seconds($0["time"]) } }
                let values = points.compactMap { (($0 as? [String: Any])?["value"] as? NSNumber)?.doubleValue }
                guard times.count == values.count, let first = times.first, times.count > 1 else { continue }
                l[series] = [
                    "startTime": round3(first),
                    "resolution": round3((times.last! - first) / Double(times.count - 1)),
                    "values": values.map { round2($0) },
                ]
            }
            out["loudness"] = l
        }

        if let ia = dict["instrumentActivity"] as? [String: Any] {
            var act: [String: Any] = [:]
            if let activity = ia["activity"] as? [String: Any] {
                for (instrument, points) in activity {
                    guard let points = points as? [Any], points.count > 1 else { continue }
                    let times = points.compactMap { ($0 as? [String: Any]).flatMap { seconds($0["time"]) } }
                    let values = points.compactMap { (($0 as? [String: Any])?["value"] as? NSNumber)?.doubleValue }
                    guard times.count == values.count, let first = times.first else { continue }
                    act[instrument] = [
                        "startTime": round3(first),
                        "resolution": round3((times.last! - first) / Double(times.count - 1)),
                        "values": values.map { round3($0) },
                    ]
                }
            }
            var ranges: [String: Any] = [:]
            if let r = ia["ranges"] as? [String: Any] {
                for (instrument, list) in r {
                    ranges[instrument] = (list as? [Any])?.compactMap(rangeSeconds)
                }
            }
            out["instrumentActivity"] = ["activity": act, "ranges": ranges]
        }

        if let sp = dict["structurePredictions"] as? [String: Any] {
            out["decodedPredictions"] = decodePredictions(sp, threshold: threshold)
        } else {
            fputs("note: structurePredictions not present in this build of the framework\n", stderr)
        }

        do {
            let words = try await transcribe(url: url)
            out["transcript"] = words
            fputs("transcribed \(words.count) words\n", stderr)
        } catch {
            fputs("note: transcription skipped (\(error.localizedDescription))\n", stderr)
        }

        let outURL = url.deletingPathExtension().appendingPathExtension("mudump.json")
        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
        try data.write(to: outURL)
        print(outURL.path)

        try writeCSVs(out, audioURL: url)
    }

    // MARK: - CSV export

    /// Writes two CSVs next to the audio file:
    /// - `.events.csv` — one row per discrete cue (beats, bars, structure boundaries), sorted by time.
    /// - `.curves.csv` — one row per 0.05s frame with all continuous channels, for table import
    ///   (TouchDesigner DAT/CHOP, lighting software, spreadsheets).
    static func writeCSVs(_ out: [String: Any], audioURL: URL) throws {
        let base = audioURL.deletingPathExtension()

        var events: [(time: Double, type: String, label: String, probability: String)] = []
        if let rhythm = out["rhythm"] as? [String: Any] {
            for (i, t) in ((rhythm["beats"] as? [Double]) ?? []).enumerated() {
                events.append((t, "beat", "\(i + 1)", ""))
            }
            for (i, t) in ((rhythm["bars"] as? [Double]) ?? []).enumerated() {
                events.append((t, "bar", "\(i + 1)", ""))
            }
        }
        if let dp = out["decodedPredictions"] as? [String: Any] {
            for level in ["sections", "segments", "phrases"] {
                guard let l = dp[level] as? [String: Any],
                      let peaks = l["boundaryPeaks"] as? [[String: Double]] else { continue }
                for (i, pk) in peaks.enumerated() {
                    guard let t = pk["time"], let p = pk["probability"] else { continue }
                    events.append((t, String(level.dropLast()), "\(i + 1)", "\(p)"))
                }
            }
        } else if let structure = out["structure"] as? [String: Any] {
            for level in ["sections", "segments", "phrases"] {
                guard let ranges = structure[level] as? [[String: Any]] else { continue }
                for (i, r) in ranges.enumerated() {
                    guard let start = r["start"] as? Double else { continue }
                    events.append((start, String(level.dropLast()), "\(i + 1)", ""))
                }
            }
        }
        if let transcript = out["transcript"] as? [[String: Any]] {
            for word in transcript {
                guard let start = word["start"] as? Double,
                      let text = word["text"] as? String else { continue }
                events.append((start, "word", text.replacingOccurrences(of: ",", with: ""), ""))
            }
        }
        events.sort { $0.time < $1.time }
        var eventsCSV = "time,type,label,probability\n"
        for e in events {
            eventsCSV += "\(e.time),\(e.type),\(e.label),\(e.probability)\n"
        }
        let eventsURL = base.appendingPathExtension("events.csv")
        try eventsCSV.write(to: eventsURL, atomically: true, encoding: .utf8)
        print(eventsURL.path)

        // Continuous channels, all resampled onto one frame grid.
        struct Channel {
            let name: String
            let startTime: Double
            let resolution: Double
            let values: [Double]

            func sample(at t: Double) -> Double? {
                let i = Int(((t - startTime) / resolution).rounded())
                guard i >= 0, i < values.count else { return nil }
                return values[i]
            }
        }

        func channel(_ name: String, _ any: Any?) -> Channel? {
            guard let d = any as? [String: Any],
                  let values = d["values"] as? [Double],
                  let resolution = d["resolution"] as? Double else { return nil }
            return Channel(name: name,
                           startTime: d["startTime"] as? Double ?? 0,
                           resolution: resolution,
                           values: values)
        }

        var channels: [Channel] = []
        if let dp = out["decodedPredictions"] as? [String: Any],
           let pace = dp["paceCurve"] as? [String: Any],
           let values = pace["expectedBin"] as? [Double],
           let resolution = pace["resolution"] as? Double {
            channels.append(Channel(name: "pace", startTime: 0, resolution: resolution, values: values))
        }
        if let ia = out["instrumentActivity"] as? [String: Any],
           let activity = ia["activity"] as? [String: Any] {
            for name in ["bass", "drum", "vocal", "other"] {
                if let c = channel(name, activity[name]) { channels.append(c) }
            }
        }
        if let loudness = out["loudness"] as? [String: Any] {
            if let c = channel("loudness_momentary", loudness["momentary"]) { channels.append(c) }
            if let c = channel("loudness_short_term", loudness["shortTerm"]) { channels.append(c) }
        }
        guard !channels.isEmpty else { return }

        let gridResolution = channels.map(\.resolution).min() ?? 0.05
        let end = channels.map { $0.startTime + Double($0.values.count) * $0.resolution }.max() ?? 0
        let frames = Int(end / gridResolution)

        var sectionRanges: [(Double, Double)] = []
        if let structure = out["structure"] as? [String: Any],
           let sections = structure["sections"] as? [[String: Any]] {
            sectionRanges = sections.compactMap { r in
                guard let s = r["start"] as? Double, let e = r["end"] as? Double else { return nil }
                return (s, e)
            }
        }

        var curvesCSV = "time," + channels.map(\.name).joined(separator: ",") + ",section\n"
        for f in 0..<frames {
            let t = Double(f) * gridResolution
            var row = String(format: "%.2f", t)
            for c in channels {
                row += ","
                if let v = c.sample(at: t) { row += "\(v)" }
            }
            let section = sectionRanges.firstIndex { t >= $0.0 && t < $0.1 }
            row += "," + (section.map { "\($0 + 1)" } ?? "")
            curvesCSV += row + "\n"
        }
        let curvesURL = base.appendingPathExtension("curves.csv")
        try curvesCSV.write(to: curvesURL, atomically: true, encoding: .utf8)
        print(curvesURL.path)
    }

    // MARK: - Lyrics transcription (SpeechAnalyzer)

    /// Transcribes the audio with the on-device SpeechAnalyzer model and returns
    /// timestamped words: `[{start, end, text}]`.
    static func transcribe(url: URL) async throws -> [[String: Any]] {
        let locale = Locale(identifier: "en-US")
        let transcriber = SpeechTranscriber(locale: locale,
                                            transcriptionOptions: [],
                                            reportingOptions: [],
                                            attributeOptions: [.audioTimeRange])

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            fputs("downloading speech model...\n", stderr)
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: url)

        async let done: Void = {
            if let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        }()

        var words: [[String: Any]] = []
        for try await result in transcriber.results where result.isFinal {
            for run in result.text.runs {
                guard let timeRange = run.audioTimeRange else { continue }
                let text = String(result.text[run.range].characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                words.append([
                    "start": round3(timeRange.start.seconds),
                    "end": round3(timeRange.end.seconds),
                    "text": text,
                ])
            }
        }
        try await done
        return words
    }

    // MARK: - Internal tensor decoding

    static func decodePredictions(_ sp: [String: Any], threshold: Float) -> [String: Any] {
        let resolution = (sp["predictionResolution"] as? NSNumber)?.doubleValue ?? 0.05
        var out: [String: Any] = [
            "predictionResolution": resolution,
            "frameworkThreshold": sp["detectionThreshold"] ?? 0.33,
        ]

        for level in ["sections", "segments", "phrases"] {
            guard let t = tensor(sp[level]) else { continue }
            out[level] = [
                "boundaryPeaks": peaks(t.data, threshold: threshold, resolution: resolution),
            ]
        }

        if let t = tensor(sp["pace"]), t.shape.count == 3 {
            let bins = t.shape[1], frames = t.shape[2]
            var expected = [Double](repeating: 0, count: frames)
            for f in 0..<frames {
                var maxLogit = -Float.infinity
                for b in 0..<bins { maxLogit = max(maxLogit, t.data[b * frames + f]) }
                var sum = 0.0, weighted = 0.0
                for b in 0..<bins {
                    let e = Double(exp(t.data[b * frames + f] - maxLogit))
                    sum += e
                    weighted += Double(b) * e
                }
                expected[f] = weighted / sum
            }
            out["paceCurve"] = [
                "resolution": resolution,
                "note": "expected pace-bin index per frame; bins are log2-spaced (events/min doubles every ~4 bins)",
                "expectedBin": expected.map { round2($0) },
            ]
        }

        if let t = tensor(sp["kinds"]), t.shape.count == 3 {
            let classes = t.shape[1], frames = t.shape[2]
            var argmax = [Int](repeating: 0, count: frames)
            for f in 0..<frames {
                var best = 0
                for c in 1..<classes where t.data[c * frames + f] > t.data[best * frames + f] { best = c }
                argmax[f] = best
            }
            out["kinds"] = ["resolution": resolution, "argmaxClass": argmax]
        }

        return out
    }

    struct Tensor {
        let shape: [Int]
        let data: [Float]
    }

    static func tensor(_ any: Any?) -> Tensor? {
        guard let d = any as? [String: Any],
              let b64 = d["scalars"] as? String,
              let shapeAny = d["shape"] as? [Any],
              let raw = Data(base64Encoded: b64) else { return nil }
        let shape = shapeAny.compactMap { ($0 as? NSNumber)?.intValue }
        let floats = raw.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
        guard floats.count == shape.reduce(1, *) else { return nil }
        return Tensor(shape: shape, data: floats)
    }

    /// Local maxima above `threshold`, merging peaks closer than `minSeparation`.
    static func peaks(_ curve: [Float], threshold: Float, resolution: Double,
                      minSeparation: Double = 2.0) -> [[String: Double]] {
        var result: [[String: Double]] = []
        guard curve.count > 2 else { return result }
        for f in 1..<(curve.count - 1) {
            let v = curve[f]
            guard v >= threshold, v >= curve[f - 1], v >= curve[f + 1] else { continue }
            let time = Double(f) * resolution
            if let last = result.last, time - last["time"]! < minSeparation {
                if Double(v) > last["probability"]! {
                    result[result.count - 1] = ["time": round3(time), "probability": round3(Double(v))]
                }
            } else {
                result.append(["time": round3(time), "probability": round3(Double(v))])
            }
        }
        return result
    }

    // MARK: - CMTime JSON helpers

    static func seconds(_ any: Any?) -> Double? {
        guard let d = any as? [String: Any],
              let value = (d["value"] as? NSNumber)?.doubleValue,
              let timescale = (d["timescale"] as? NSNumber)?.doubleValue,
              timescale != 0 else { return nil }
        return round3(value / timescale)
    }

    static func rangeSeconds(_ any: Any?) -> [String: Any]? {
        guard let d = any as? [String: Any],
              let start = seconds(d["start"]),
              let duration = seconds(d["duration"]) else { return nil }
        return ["start": start, "end": round3(start + duration)]
    }

    static func round3(_ x: Double) -> Double { (x * 1000).rounded() / 1000 }
    static func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }
}
