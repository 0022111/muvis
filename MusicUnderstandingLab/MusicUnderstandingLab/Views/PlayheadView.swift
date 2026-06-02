/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The vertical playhead indicator with tap-to-seek interaction.
*/
import AVFoundation
import SwiftUI

/// Displays a vertical playhead line and handles tap-to-seek interactions.
struct PlayheadView: View {

    private enum Constants {
        static let lineWidth: CGFloat = 2
        static let edgeToleranceFraction: Double = 0.01
        static let playheadOpacity: Double = 0.7
    }

    @Environment(AssetPlayer.self) var assetPlayer
    @State private var viewWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            TimelineView(.animation(paused: !assetPlayer.isPlaying)) { _ in
                let time = assetPlayer.isPlaying
                    ? assetPlayer.player.currentTime().seconds
                    : assetPlayer.currentTime
                let duration = assetPlayer.duration
                let progress = duration > 0 ? time / duration : 0

                if progress >= -Constants.edgeToleranceFraction && progress <= 1 + Constants.edgeToleranceFraction {
                    Rectangle()
                        .fill(Color(.playhead).opacity(Constants.playheadOpacity))
                        .frame(width: Constants.lineWidth)
                        .offset(x: viewWidth * min(max(progress, 0), 1))
                }
            }

            // Tap to seek
            Color.clear.contentShape(Rectangle())
                .onTapGesture { location in
                    let fraction = location.x / viewWidth
                    let seconds = fraction * assetPlayer.duration
                    assetPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: assetPlayer.sampleRate))
                }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            viewWidth = newWidth
        }
    }
}
