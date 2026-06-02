/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The prominent BPM display with animated beat indicators.
*/
import CoreMedia
import MusicUnderstanding
import SwiftUI

/// Displays the detected rhythm as a hero BPM value with animated beat indicators.
struct RhythmView: View {

    private enum Constants {
        static let beatsPerMinuteSpacing: CGFloat = 6
        static let beatsPerMinuteFontSize: CGFloat = 48
        static let beatsPerMinuteLabelFontSize: CGFloat = 20
        static let beatIndicatorHeight: CGFloat = 8
        static let beatIndicatorWidth: CGFloat = 30
        static let beatIndicatorActiveDownbeatOpacity: CGFloat = 0.8
        static let beatIndicatorActiveBeatOpacity: CGFloat = 0.45
        static let beatIndicatorInactiveDownbeatOpacity: CGFloat = 0.25
        static let beatIndicatorInactiveBeatOpacity: CGFloat = 0.1
        static let beatIndicatorActiveShadowOpacity: Double = 0.5
        static let beatIndicatorCornerRadius: CGFloat = 4
        static let beatIndicatorSpacing: CGFloat = 8
        static let activeShadowRadius: CGFloat = 4
        static let inactiveShadowRadius: CGFloat = 0
        static let inactiveAnimationDuration: TimeInterval = 0.15
        static let stackYOffset: CGFloat = -8
    }

    let rhythmResult: RhythmResult

    @Environment(AssetPlayer.self) private var player

    /// The number of beats per bar.
    private var beatsPerBar: Int {
        let barCount = rhythmResult.bars.count
        let beatCount = rhythmResult.beats.count
        guard barCount >= 2, beatCount > 0 else { return 4 }
        let avg = Double(beatCount) / Double(barCount - 1)
        let rounded = Int(avg.rounded())
        return max(min(rounded, 7), 2)
    }

    /// The current beat index (1-based) based on playback time.
    private var currentBeat: Int {
        let time = player.currentTime
        let beats = rhythmResult.beats.map(\.seconds)
        guard beats.count >= 2 else { return 1 }

        let bars = rhythmResult.bars.map(\.seconds)

        // If playback is before the first bar, just return beat 1
        guard let barTime = bars.last(where: { $0 <= time }) else {
            return 1
        }

        let beatsSinceBar = beats.filter { $0 > barTime && $0 <= time }.count + 1

        return max(1, min(beatsSinceBar, beatsPerBar))
    }

    var body: some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: Constants.beatsPerMinuteSpacing) {

                Text(rhythmResult.beatsPerMinute.map { "\(Int($0))" } ?? "—")
                    .font(.system(size: Constants.beatsPerMinuteFontSize, weight: .bold))
                    .lineLimit(1)
                    .contentTransition(.numericText())

                Text("BPM")
                    .font(.system(size: Constants.beatsPerMinuteLabelFontSize, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rhythmResult.beatsPerMinute.map { "\(Int($0)) beats per minute" } ??
                                "No tempo detected")

            if rhythmResult.beatsPerMinute != nil {
                HStack(spacing: Constants.beatIndicatorSpacing) {
                    ForEach(1...beatsPerBar, id: \.self) { beat in
                        let isDownbeat = beat == 1
                        let isActive = player.isPlaying && beat == currentBeat
                        let activeBeatIndicatorOpacity = isDownbeat ? Constants.beatIndicatorActiveDownbeatOpacity :
                        Constants.beatIndicatorActiveBeatOpacity
                        let inactiveBeatIndicatorOpacity = isDownbeat ? Constants.beatIndicatorInactiveDownbeatOpacity :
                        Constants.beatIndicatorInactiveBeatOpacity

                        RoundedRectangle(cornerRadius: Constants.beatIndicatorCornerRadius)
                            .fill(.white.opacity(isActive ? activeBeatIndicatorOpacity : inactiveBeatIndicatorOpacity))
                            .frame(
                                width: Constants.beatIndicatorWidth,
                                height: Constants.beatIndicatorHeight
                            )
                            .shadow(
                                color: isActive ? .white.opacity(Constants.beatIndicatorActiveShadowOpacity) : .clear,
                                radius: isActive ? Constants.activeShadowRadius : Constants.inactiveShadowRadius
                            )
                            .animation(isActive ? nil : .easeOut(duration: Constants.inactiveAnimationDuration), value: isActive)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
        .offset(y: Constants.stackYOffset)
    }
}
