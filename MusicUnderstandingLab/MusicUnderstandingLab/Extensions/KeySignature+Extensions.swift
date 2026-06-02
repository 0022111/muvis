/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Display name extensions for key signature tonics and modes.
*/
import MusicUnderstanding

extension KeyResult.Tonic {
    /// The human-readable name for this tonic (e.g. "C#", "Bb").
    var displayName: String {
        switch self {
        case .a: "A"
        case .aFlat: "A♭"
        case .aSharp: "A♯"
        case .b: "B"
        case .bFlat: "B♭"
        case .c: "C"
        case .cSharp: "C♯"
        case .d: "D"
        case .dFlat: "D♭"
        case .dSharp: "D♯"
        case .e: "E"
        case .eFlat: "E♭"
        case .f: "F"
        case .fSharp: "F♯"
        case .g: "G"
        case .gFlat: "G♭"
        case .gSharp: "G♯"
        }
    }
}

extension KeyResult.Mode {
    /// The human-readable name for this mode (e.g. "Major", "Minor").
    var displayName: String {
        switch self {
        case .major: "Major"
        case .minor: "Minor"
        @unknown default: ""
        }
    }
}
