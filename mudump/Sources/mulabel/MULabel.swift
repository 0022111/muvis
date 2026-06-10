import Foundation
import FoundationModels

/// Labels the sections of a `.mudump.json` file using the on-device Foundation
/// Models LLM, writing `label`, `hype`, and `reason` into each section in place.
@main
struct MULabel {

    @Generable
    struct SectionLabel {
        @Guide(description: "Section number, starting at 1, matching the input order")
        var index: Int
        @Guide(description: "Exactly one of: intro, verse, buildup, drop, breakdown, bridge, outro")
        var kind: String
        @Guide(description: "Reason for the label, at most eight words")
        var reason: String
    }

    @Generable
    struct SectionLabels {
        @Guide(description: "One entry per section, in the same order as the input")
        var sections: [SectionLabel]
    }

    static func main() async {
        guard CommandLine.arguments.count > 1 else {
            fputs("usage: mulabel <file.mudump.json> ...\n", stderr)
            exit(64)
        }
        guard case .available = SystemLanguageModel.default.availability else {
            fputs("error: on-device language model unavailable: \(SystemLanguageModel.default.availability)\n", stderr)
            exit(1)
        }
        for path in CommandLine.arguments.dropFirst() {
            do {
                try await label(path: path)
            } catch {
                fputs("error: \(path): \(error)\n", stderr)
                exit(1)
            }
        }
    }

    static func label(path: String) async throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let data = try Data(contentsOf: url)
        guard var dump = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var structure = dump["structure"] as? [String: Any],
              var sections = structure["sections"] as? [[String: Any]],
              !sections.isEmpty else {
            throw NSError(domain: "mulabel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no structure.sections in file"])
        }

        let (stats, hypes) = sectionStats(dump: dump, sections: sections)
        let prompt = """
        Label each section of an electronic music track (dubstep/trap style) using \
        ONLY the energy ranks given. Rank 1 = most energetic section of the track.
        Rules, apply in order:
        - energy rank in the top third AND loud: "drop"
        - quiet section that comes AFTER a drop: "breakdown"
        - section quieter than the NEXT section: "buildup"
        - first section if quiet: "intro"; last section if quiet: "outro"
        - otherwise: "verse"
        Output exactly \(sections.count) entries, index 1 to \(sections.count), in order.

        \(stats)
        """

        fputs("labeling \(sections.count) sections...\n", stderr)
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt, generating: SectionLabels.self)
        let labels = response.content.sections

        for label in labels {
            let i = label.index - 1
            guard i >= 0, i < sections.count else { continue }
            let hype = i < hypes.count ? hypes[i] : 5
            sections[i]["label"] = label.kind
            sections[i]["hype"] = hype
            sections[i]["reason"] = label.reason
            fputs(String(format: "  %2d  %6.1fs  %-10s hype=%2d  %@\n",
                         label.index,
                         sections[i]["start"] as? Double ?? 0,
                         (label.kind as NSString).utf8String!,
                         hype, label.reason), stderr)
        }

        structure["sections"] = sections
        dump["structure"] = structure
        let outData = try JSONSerialization.data(withJSONObject: dump, options: [.sortedKeys])
        try outData.write(to: url)
        print(url.path)
    }

    /// One compact line of numeric evidence per section, plus a deterministic
    /// hype score (1-10) derived from the blended energy — never ask an LLM
    /// to do arithmetic.
    static func sectionStats(dump: [String: Any], sections: [[String: Any]]) -> (String, [Int]) {
        func series(_ any: Any?) -> (start: Double, resolution: Double, values: [Double])? {
            guard let d = any as? [String: Any],
                  let values = d["values"] as? [Double],
                  let resolution = d["resolution"] as? Double else { return nil }
            return (d["startTime"] as? Double ?? 0, resolution, values)
        }
        func mean(_ s: (start: Double, resolution: Double, values: [Double])?,
                  from: Double, to: Double) -> Double? {
            guard let s else { return nil }
            let lo = max(0, Int((from - s.start) / s.resolution))
            let hi = min(s.values.count, Int((to - s.start) / s.resolution))
            guard hi > lo else { return nil }
            return s.values[lo..<hi].reduce(0, +) / Double(hi - lo)
        }

        let activity = (dump["instrumentActivity"] as? [String: Any])?["activity"] as? [String: Any]
        let loudness = dump["loudness"] as? [String: Any]
        let bass = series(activity?["bass"])
        let drum = series(activity?["drum"])
        let vocal = series(activity?["vocal"])
        let loud = series(loudness?["momentary"])

        var pace: (start: Double, resolution: Double, values: [Double])?
        if let dp = dump["decodedPredictions"] as? [String: Any],
           let pc = dp["paceCurve"] as? [String: Any],
           let values = pc["expectedBin"] as? [Double],
           let resolution = pc["resolution"] as? Double {
            pace = (0, resolution, values)
        }

        // Precompute a single energy score and rank per section so the model
        // compares ranks instead of doing arithmetic (small models can't).
        struct Row {
            let index: Int
            let start: Double
            let end: Double
            let energy: Double
            let vocals: Double
        }
        var rows: [Row] = []
        for (i, section) in sections.enumerated() {
            guard let start = section["start"] as? Double,
                  let end = section["end"] as? Double else { continue }
            // Normalize loudness (-25..-5 → 0..1) and pace (8..25 → 0..1), then blend.
            let l = mean(loud, from: start, to: end).map { min(1, max(0, ($0 + 25) / 20)) } ?? 0
            let p = mean(pace, from: start, to: end).map { min(1, max(0, ($0 - 8) / 17)) } ?? 0
            let b = mean(bass, from: start, to: end) ?? 0
            let d = mean(drum, from: start, to: end) ?? 0
            rows.append(Row(index: i + 1, start: start, end: end,
                            energy: l * 0.4 + p * 0.3 + b * 0.15 + d * 0.15,
                            vocals: mean(vocal, from: start, to: end) ?? 0))
        }
        let ranked = rows.sorted { $0.energy > $1.energy }
        var rank: [Int: Int] = [:]
        for (r, row) in ranked.enumerated() { rank[row.index] = r + 1 }

        let maxEnergy = max(0.001, ranked.first?.energy ?? 1)
        let hypes = rows.map { max(1, min(10, Int(($0.energy / maxEnergy * 10).rounded()))) }

        let lines = rows.map { row in
            let r = rank[row.index] ?? rows.count
            let tier = r <= rows.count / 3 ? "LOUD"
                : r > (rows.count * 2) / 3 ? "quiet" : "medium"
            return String(format: "section %d: %.0f-%.0fs, energy rank %d of %d (%@), vocals %.2f",
                          row.index, row.start, row.end, r, rows.count, tier, row.vocals)
        }.joined(separator: "\n")
        return (lines, hypes)
    }
}
