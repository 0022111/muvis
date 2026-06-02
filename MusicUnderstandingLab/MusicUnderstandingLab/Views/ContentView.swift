/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The root view that manages song selection, analysis, and navigation to the visualization.
*/
import AVFoundation
import MusicUnderstanding
import SwiftUI

/// The root view that manages song selection, analysis, and navigation to the visualization.
struct ContentView: View {

    private enum Constants {
        static let animationDuration: Double = 0.5
    }

    @State private var analyzer: AssetAnalyzer?
    @State private var audioPlayer = AssetPlayer()
    @State private var showingVisualization = false
    @State private var isAccessingSecurityScopeResource = false
    @State private var securityScopedURL: URL?
    @State private var analysisError: Error?

    var body: some View {
        NavigationStack {
            SongSelectionView { url in
                stopAccessingSecurityScopedResource()
                let isBundleURL = url.path().hasPrefix(Bundle.main.bundlePath)
                if !isBundleURL {
                    securityScopedURL = url
                    isAccessingSecurityScopeResource = url.startAccessingSecurityScopedResource()
                    guard isAccessingSecurityScopeResource else { return }
                }
                let asset = AVURLAsset(url: url, options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: true
                ])
                analyzer = AssetAnalyzer(asset: asset)
                showingVisualization = true
            }
            .navigationDestination(isPresented: $showingVisualization) {
                if let analyzer {
                    VisualizationView()
                        .environment(analyzer)
                }
            }
        }
        .task(id: analyzer?.asset.url) {
            guard let analyzer else { return }
            async let loadTask: Void = audioPlayer.load(AVPlayerItem(asset: analyzer.asset))
            do {
                async let analyzeTask: Void = analyzer.analyze()
                _ = await loadTask
                try await analyzeTask
            } catch is CancellationError {
                // Expected when the user navigates away before analysis finishes.
            } catch {
                // Analysis failed
                analysisError = error
            }
        }
        .alert("Couldn’t Analyze Song",
               isPresented: Binding(get: { analysisError != nil },
                                    set: { if !$0 { analysisError = nil } }),
               presenting: analysisError) { _ in
            Button("Choose Another Song") { showingVisualization = false }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: showingVisualization) { _, isShowing in
            if !isShowing {
                audioPlayer.stop()
                stopAccessingSecurityScopedResource()
                analyzer = nil
            }
        }
        .animation(.smooth(duration: Constants.animationDuration), value: analyzer?.result != nil)
        .environment(audioPlayer)
        .preferredColorScheme(.dark)
    }

    private func stopAccessingSecurityScopedResource() {
        if isAccessingSecurityScopeResource, let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopeResource = false
            securityScopedURL = nil
        }
    }
}
