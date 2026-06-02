/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The bar chart that shows when each instrument is active during the song.
*/
import Charts
import CoreMedia
import MusicUnderstanding
import SwiftUI

/// Displays horizontal bars showing when each instrument is active.
struct InstrumentRangesView: View {

    private enum Constants {
        static let barCornerRadius: CGFloat = 8
        static let colorOpacity = 0.9
    }

    /// The instrument activity analysis result containing range data.
    let result: InstrumentActivityResult

    @Environment(AssetPlayer.self) var assetPlayer

    var body: some View {
        ZStack {
            Chart {
                ForEach(InstrumentActivityResult.Instrument.displayOrder, id: \.rawValue) { instrument in
                    if let ranges = result.ranges[instrument] {
                        ForEach(ranges, id: \.self) { range in
                            BarMark(
                                xStart: .value("Start", range.start.seconds),
                                xEnd: .value("End", (range.start + range.duration).seconds),
                                y: .value("Instrument", instrument.rawValue.capitalized)
                            )
                            .foregroundStyle(instrument.color.opacity(Constants.colorOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: Constants.barCornerRadius))
                        }
                    }
                }
            }
            .chartXScale(domain: .zero...max(assetPlayer.duration, 1.0))
            .chartXAxis(.hidden)
        }
    }
}
