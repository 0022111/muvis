/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The visualization of pace analysis as proportionally sized clip rectangles.
*/
import CoreMedia
import MusicUnderstanding
import SwiftUI

/// Displays pace analysis as clip rectangles.
struct PaceView: View {

    private enum Constants {
        static let maxHeightFraction: Double = 0.7
        static let labelMinWidth: CGFloat = 30
        static let clipCornerRadius: CGFloat = 5
        static let clipBorderThreshold: CGFloat = 4
        static let clipBorderWidth: CGFloat = 1
        static let secondsPerMinute: Double = 60.0
        static let fillOpacity: Double = 0.9
    }

    /// The pace analysis result
    let paceResult: PaceResult

    @Environment(AssetPlayer.self) var assetPlayer
    @State var viewSize: CGSize = .zero

    var body: some View {
        let totalDuration = assetPlayer.duration
        let maxPace = max(paceResult.ranges.map(\.value).max() ?? .zero, 1)

        ZStack(alignment: .leading) {
            Color.clear

            if totalDuration > .zero {
                ForEach(paceResult.ranges.indices, id: \.self) { rangeIndex in
                    let rangedValue = paceResult.ranges[rangeIndex]
                    let rangeStart = rangedValue.range.start.seconds
                    let rangeEnd = (rangedValue.range.start + rangedValue.range.duration).seconds
                    let rangeDuration = rangeEnd - rangeStart

                    if rangeEnd > .zero && rangeStart < totalDuration {
                        let sectionWidth = (rangeDuration / totalDuration) * viewSize.width
                        let xOffset = (rangeStart / totalDuration) * viewSize.width
                        let height = (rangedValue.value / maxPace) * viewSize.height * Constants.maxHeightFraction

                        VStack(spacing: .zero) {
                            Spacer(minLength: .zero)
                            paceClips(
                                pace: rangedValue.value,
                                sectionDuration: rangeDuration,
                                width: sectionWidth,
                                height: height
                            )
                            Text(String(format: "%.0f", rangedValue.value))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize()
                                .opacity(sectionWidth > Constants.labelMinWidth ? 1 : .zero)
                        }
                        .frame(width: sectionWidth, height: viewSize.height)
                        .offset(x: xOffset)
                    }
                }
            }
        }
        .clipped()
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            viewSize = newSize
        }
    }

    private func paceClips(pace: Double, sectionDuration: Double, width: Double, height: Double) -> some View {
        let timePerClip = Constants.secondsPerMinute / pace
        let clipCount = min(max(Int(sectionDuration / timePerClip), 1), max(Int(width), 1))
        let clipWidth = width / Double(clipCount)

        return HStack(spacing: .zero) {
            ForEach(0..<clipCount, id: \.self) { _ in
                let cornerRadius = Constants.clipCornerRadius
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.paceValue).opacity(Constants.fillOpacity))
                    .overlay {
                        if clipWidth > Constants.clipBorderThreshold {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(Color(.paceClipBorder), lineWidth: Constants.clipBorderWidth)
                        }
                    }
                    .frame(height: height)
            }
        }
        .frame(width: width)
    }
}
