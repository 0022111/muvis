/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The playback controls bar with time display and volume slider.
*/
import SwiftUI

/// Displays playback controls, time display, and volume slider.
struct TransportBarView: View {

    private enum Constants {
        static let buttonSize: CGFloat = 44
        static let volumeSliderWidth: CGFloat = 100
        static let timeMinWidth: CGFloat = 100
        static let animationDuration: TimeInterval = 0.15
    }

    @Environment(AssetPlayer.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        @Bindable var bindablePlayer = player
        HStack {
            Text(player.formattedCurrentTime)
                .font(sizeClass == .regular ? .title2.bold().monospacedDigit() : .title3.bold().monospacedDigit())
                .contentTransition(.numericText())
                .frame(minWidth: Constants.timeMinWidth)

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
                    .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                    .background(Color(.transportBarButtonBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: Constants.animationDuration), value: player.isPlaying)
            .keyboardShortcut(" ", modifiers: [])

            Slider(value: $bindablePlayer.volume, in: 0...1)
                .frame(width: Constants.volumeSliderWidth)

            Spacer()
        }
    }
}
