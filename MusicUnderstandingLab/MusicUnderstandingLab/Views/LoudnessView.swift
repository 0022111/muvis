/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The view that displays loudness statistics and a momentary loudness chart.
*/
import MusicUnderstanding
import SwiftUI

/// Displays loudness statistics and a momentary loudness chart.
struct LoudnessView: View {

    private enum Constants {
        static let contentSpacing: CGFloat = 12
        static let statsSpacing: CGFloat = 40
        static let chartSpacing: CGFloat = 4
        static let loudnessMin: Float = -60
        static let loudnessMid: Float = -30
        static let loudnessMax: Float = 0
    }

    /// The loudness analysis result
    let loudnessResult: LoudnessResult

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            statsRow(loudness: loudnessResult)

            ChartSection(title: "Momentary Loudness", data: loudnessResult.momentary)
        }
    }

    private func statsRow(loudness: LoudnessResult) -> some View {
        HStack(spacing: Constants.statsSpacing) {
            statItem(label: "Peak", value: String(format: "%.2f dB", loudness.peak.value))
            statItem(label: "Integrated Loudness", value: String(format: "%.2f LUFS", loudness.integrated.value))
        }
        .padding(.horizontal)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color(.loudnessValue))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private struct ChartSection: View {
        let title: String
        let data: [MusicUnderstandingSession.TimedValue<Float>]

        var body: some View {
            VStack(alignment: .leading, spacing: Constants.chartSpacing) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TimeSeriesChartView(
                    data: data,
                    color: Color(.loudnessValue),
                    minValue: Constants.loudnessMin,
                    maxValue: Constants.loudnessMax,
                    gridlineValues: [Constants.loudnessMax, Constants.loudnessMid, Constants.loudnessMin]
                )
                .overlay {
                    PlayheadView()
                }
            }
        }
    }
}
