/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The prominent text display for the detected musical key signature.
*/
import MusicUnderstanding
import SwiftUI

/// Displays the detected key as hero text (e.g. "C♯ Major").
struct KeyView: View {

    let keySignature: KeyResult.KeySignature

    private enum Constants {
        static let tonicFontSize: CGFloat = 48
        static let modeFontSize: CGFloat = 20
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(keySignature.tonic.displayName)
                .font(.system(size: Constants.tonicFontSize, weight: .bold))
                .lineLimit(1)

            Text(keySignature.mode.displayName)
                .font(.system(size: Constants.modeFontSize, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .offset(y: -8)
        .accessibilityElement(children: .combine)
    }
}
