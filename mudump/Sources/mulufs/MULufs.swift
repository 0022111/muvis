import AVFoundation
import Foundation
import MusicUnderstanding

/// Loudness-only analysis: prints one JSON object to stdout, fast.
/// Used by the Ableton "LUFS Meter" extension.
@main
struct MULufs {

    static func main() async {
        guard CommandLine.arguments.count > 1 else {
            fputs("usage: mulufs <audiofile>\n", stderr)
            exit(64)
        }
        do {
            try await measure(path: CommandLine.arguments[1])
        } catch {
            let message = (error as NSError).localizedDescription
            print(#"{"error": "\#(message.replacingOccurrences(of: "\"", with: "'"))"}"#)
            exit(1)
        }
    }

    static func measure(path: String) async throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let session = try await MusicUnderstandingSession(asset: asset)
        let result = try await session.analyze(for: [.loudness])

        guard let loudness = result.loudness else {
            print(#"{"error": "no loudness result"}"#)
            exit(1)
        }

        func r2(_ x: Float) -> Double { (Double(x) * 100).rounded() / 100 }

        var out: [String: Any] = [
            "file": url.lastPathComponent,
            "integratedLUFS": r2(loudness.integrated.value),
            "peak": [
                "value": r2(loudness.peak.value),
                "time": (loudness.peak.time.seconds * 100).rounded() / 100,
            ],
        ]
        let shortTerm = loudness.shortTerm.map(\.value)
        let momentary = loudness.momentary.map(\.value)
        if let m = shortTerm.max() { out["shortTermMaxLUFS"] = r2(m) }
        if let m = momentary.max() { out["momentaryMaxLUFS"] = r2(m) }
        // Downsample momentary to <=120 points for the dialog sparkline.
        if !momentary.isEmpty {
            let stride = max(1, momentary.count / 120)
            out["sparkline"] = momentary.enumerated()
                .filter { $0.offset % stride == 0 }
                .map { r2($0.element) }
        }

        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
}
