/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The video player view that displays a composition synced to the song.
*/
import AVKit
import MusicUnderstanding
import SwiftUI

/// Displays a video synced to the song.
struct VideoView: View {

    private enum Constants {
        static let aspectRatio: CGFloat = 9 / 16
        static let videoHeight: CGFloat = 430
        static let cornerRadius: CGFloat = 12
        static let animationDuration: TimeInterval = 0.4
    }

    @Environment(AssetAnalyzer.self) var analyzer
    @Environment(AssetPlayer.self) var assetPlayer

    @State private var isReady = false

    var body: some View {
        VideoPlayer(player: assetPlayer.player)
            .aspectRatio(Constants.aspectRatio, contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .frame(maxWidth: .infinity)
            .frame(height: Constants.videoHeight)
            .opacity(isReady ? 1 : 0)
            .animation(.easeIn(duration: Constants.animationDuration), value: isReady)
            .mask(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .padding([.top, .horizontal])
        .task(id: analyzer.pace != nil && analyzer.structure != nil) {
            isReady = false
            guard let pace = analyzer.pace,
                  let sections = analyzer.structure?.sections else { return }

            let composer = VideoComposer(
                paceRanges: pace.ranges,
                sections: sections,
                songURL: analyzer.asset.url
            )

            guard let asset = try? await composer.compose() else { return }
            let playerItem = AVPlayerItem(asset: asset)
            await assetPlayer.load(playerItem, preservePlayback: true)
            isReady = true
        }
    }
}
