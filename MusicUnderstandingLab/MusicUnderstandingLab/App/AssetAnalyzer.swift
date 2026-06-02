/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The musical asset top-level analysis controller.
*/
import AVFoundation
import MusicUnderstanding
import os

/// Analyzes an audio asset using the MusicUnderstanding framework.
@Observable @MainActor
final class AssetAnalyzer {

    /// The audio asset to analyze.
    let asset: AVURLAsset

    /// The result of the most recent analysis, if any.
    private(set) var result: MusicUnderstandingSession.SessionResult?

    /// Protects against duplicate calls to `analyze()`
    private(set) var isAnalyzing = false

    /// The asset's filename without extension, suitable for display.
    var displayName: String {
        asset.url.deletingPathExtension().lastPathComponent
    }

    var rhythm: RhythmResult? { result?.rhythm }
    var loudness: LoudnessResult? { result?.loudness }
    var instrumentActivity: InstrumentActivityResult? { result?.instrumentActivity }
    var structure: StructureResult? { result?.structure }
    var pace: PaceResult? { result?.pace }
    var key: KeyResult? { result?.key }

    /// Creates an analyzer for the given audio asset.
    ///
    /// - Parameter asset: The audio asset to analyze.
    init(asset: AVURLAsset) {
        self.asset = asset
    }

    /// Runs all supported MusicUnderstanding analyses on the asset.
    ///
    /// - Throws: `AnalysisError/protectedContent` if the asset is DRM-protected,
    ///   or an error from the MusicUnderstanding session or analysis if it fails.
    func analyze() async throws {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        result = nil

        // DRM-protected assets can't be decoded for analysis.
        let isProtected = try await asset.load(.hasProtectedContent)
        guard !isProtected else { throw AnalysisError.protectedContent }

        let session = try await MusicUnderstandingSession(asset: asset)

        self.result = try await session.analyze()
    }

    /// Errors surfaced to the user when analysis can't proceed.
    enum AnalysisError: Error {

        /// The asset is DRM-protected (for example, an Apple Music download) and can't be decoded.
        case protectedContent

        var errorDescription: String? {
            switch self {
            case .protectedContent:
                "The selected song is using a protected or unsupported format. Please choose a different song to analyze."
            }
        }
    }
}
