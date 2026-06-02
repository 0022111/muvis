/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The reusable line chart for rendering time-series data.
*/
import Charts
import CoreMedia
import MusicUnderstanding
import SwiftUI

/// A chart view for rendering time-series data as line marks.
struct TimeSeriesChartView: View {

    @Environment(AssetPlayer.self) var assetPlayer

    /// The time-series data points to chart.
    let data: [MusicUnderstandingSession.TimedValue<Float>]

    /// The color used for the chart line.
    var color: Color = .purple

    /// The minimum Y-axis value.
    var minValue: Float = 0

    /// The maximum Y-axis value.
    var maxValue: Float = 1

    /// Y-axis gridline positions.
    var gridlineValues: [Float]?

    private enum Constants {
        static let chartOpacity: Double = 0.9
    }

    var body: some View {
        Chart(Array(data.enumerated()), id: \.offset) { _, point in
            let value = max(min(point.value, maxValue), minValue)
            LineMark(
                x: .value("Time", point.time.seconds),
                y: .value("Value", value)
            )
            .foregroundStyle(color.opacity(Constants.chartOpacity))
            .interpolationMethod(.linear)
        }
        .chartXScale(domain: 0...assetPlayer.duration)
        .chartYScale(domain: Double(minValue)...Double(maxValue))
        .chartXAxis(.hidden)
        .chartYAxis {
            if let gridlineValues {
                AxisMarks(values: gridlineValues.map { Double($0) }) {
                    AxisGridLine()
                }
            }
        }
    }
}
