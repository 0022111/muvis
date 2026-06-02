/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The line chart that displays a single instrument's activity level over time.
*/
import MusicUnderstanding
import SwiftUI

/// Displays a single instrument's activity level over time as a line chart.
struct InstrumentActivityView: View {

    /// The instrument whose activity is being displayed.
    let instrument: InstrumentActivityResult.Instrument

    /// The time-series activity data for this instrument.
    let activity: [MusicUnderstandingSession.TimedValue<Float>]

    private enum Constants {
        static let gridlineValues: [Float] = [0, 0.25, 0.5, 1.0]
    }

    var body: some View {
        if !activity.isEmpty {
            TimeSeriesChartView(
                data: activity,
                color: instrument.color,
                gridlineValues: Constants.gridlineValues
            )
        }
    }
}
