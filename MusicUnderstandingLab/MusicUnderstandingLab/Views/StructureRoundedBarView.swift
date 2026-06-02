/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The colored segment bar that visualizes song structure time ranges.
*/
import CoreMedia
import SwiftUI

private enum Constants {
    static let segmentGap: CGFloat = 2
    static let segmentCornerRadius: CGFloat = 3
    static let activeOpacity: Double = 0.75
    static let inactiveOpacity: Double = 0.20
    static let fadeOutDuration: Double = 0.15
}

/// Displays a row of colored segments representing song structure ranges.
struct StructureRoundedBarView: View {

    /// The time ranges to render as colored segments.
    let ranges: [CMTimeRange]

    /// The tint color for the segments.
    var tint: Color = .purple

    @Environment(AssetPlayer.self) var player
    @State var viewSize: CGSize = .zero

    var body: some View {
        Color.clear
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                viewSize = newSize
            }
            .overlay(alignment: .leading) {
                let totalDuration = player.duration
                let currentTime = player.currentTime

                if totalDuration > 0 {
                    ZStack(alignment: .leading) {
                        ForEach(Array(ranges.enumerated()), id: \.offset) { _, range in
                            let rangeStart = range.start.seconds
                            let rangeEnd = (range.start + range.duration).seconds

                            if rangeEnd > 0 && rangeStart < totalDuration {
                                let effectiveStart = max(rangeStart, 0)
                                let effectiveEnd = min(rangeEnd, totalDuration)
                                let gap: CGFloat = Constants.segmentGap
                                let rawWidth = ((effectiveEnd - effectiveStart) / totalDuration) * viewSize.width
                                let width = max(rawWidth - gap, 0)
                                let xOffset = (effectiveStart / totalDuration) * viewSize.width

                                let isActive = player.isPlaying && currentTime >= rangeStart && currentTime < rangeEnd

                                SegmentBar(tint: tint, isActive: isActive, isPlaying: player.isPlaying)
                                    .frame(width: width, height: viewSize.height)
                                    .offset(x: xOffset)
                            }
                        }
                    }
                }
            }
    }
}

private struct SegmentBar: View {
    let tint: Color
    let isActive: Bool
    let isPlaying: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: Constants.segmentCornerRadius, style: .continuous)
            .fill(isActive ? tint.opacity(Constants.activeOpacity) : tint.opacity(Constants.inactiveOpacity))
            .animation(isPlaying ? .none : .easeInOut(duration: Constants.fadeOutDuration), value: isActive)
    }
}
