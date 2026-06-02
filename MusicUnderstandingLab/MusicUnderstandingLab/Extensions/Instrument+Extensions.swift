/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Display properties for instrument types, including colors and ordering.
*/
import MusicUnderstanding
import SwiftUI

extension InstrumentActivityResult.Instrument {
    /// The canonical display order for all instruments.
    static let displayOrder: [InstrumentActivityResult.Instrument] = [.vocal, .drum, .bass, .other]

    /// The color associated with this instrument from the asset catalog.
    var color: Color {
        switch self {
        case .vocal: Color(.activityVocal)
        case .drum: Color(.activityDrum)
        case .bass: Color(.activityBass)
        case .other: Color(.activityOther)
        default: .white
        }
    }
}
