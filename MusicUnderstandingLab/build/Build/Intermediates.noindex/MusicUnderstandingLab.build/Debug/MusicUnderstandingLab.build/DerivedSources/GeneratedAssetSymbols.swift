import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "Activity_BassColor" asset catalog color resource.
    static let activityBass = DeveloperToolsSupport.ColorResource(name: "Activity_BassColor", bundle: resourceBundle)

    /// The "Activity_DrumColor" asset catalog color resource.
    static let activityDrum = DeveloperToolsSupport.ColorResource(name: "Activity_DrumColor", bundle: resourceBundle)

    /// The "Activity_OtherColor" asset catalog color resource.
    static let activityOther = DeveloperToolsSupport.ColorResource(name: "Activity_OtherColor", bundle: resourceBundle)

    /// The "Activity_VocalColor" asset catalog color resource.
    static let activityVocal = DeveloperToolsSupport.ColorResource(name: "Activity_VocalColor", bundle: resourceBundle)

    /// The "Loudness_ValueColor" asset catalog color resource.
    static let loudnessValue = DeveloperToolsSupport.ColorResource(name: "Loudness_ValueColor", bundle: resourceBundle)

    /// The "Pace_ClipBorderColor" asset catalog color resource.
    static let paceClipBorder = DeveloperToolsSupport.ColorResource(name: "Pace_ClipBorderColor", bundle: resourceBundle)

    /// The "Pace_ValueColor" asset catalog color resource.
    static let paceValue = DeveloperToolsSupport.ColorResource(name: "Pace_ValueColor", bundle: resourceBundle)

    /// The "PlayheadColor" asset catalog color resource.
    static let playhead = DeveloperToolsSupport.ColorResource(name: "PlayheadColor", bundle: resourceBundle)

    /// The "Structure_PhraseColor" asset catalog color resource.
    static let structurePhrase = DeveloperToolsSupport.ColorResource(name: "Structure_PhraseColor", bundle: resourceBundle)

    /// The "Structure_SectionColor" asset catalog color resource.
    static let structureSection = DeveloperToolsSupport.ColorResource(name: "Structure_SectionColor", bundle: resourceBundle)

    /// The "Structure_SegmentColor" asset catalog color resource.
    static let structureSegment = DeveloperToolsSupport.ColorResource(name: "Structure_SegmentColor", bundle: resourceBundle)

    /// The "Tile_BackgroundColor" asset catalog color resource.
    static let tileBackground = DeveloperToolsSupport.ColorResource(name: "Tile_BackgroundColor", bundle: resourceBundle)

    /// The "TransportBar_BackgroundColor" asset catalog color resource.
    static let transportBarBackground = DeveloperToolsSupport.ColorResource(name: "TransportBar_BackgroundColor", bundle: resourceBundle)

    /// The "TransportBar_ButtonBackgroundColor" asset catalog color resource.
    static let transportBarButtonBackground = DeveloperToolsSupport.ColorResource(name: "TransportBar_ButtonBackgroundColor", bundle: resourceBundle)

    /// The "TransportBar_SeparatorColor" asset catalog color resource.
    static let transportBarSeparator = DeveloperToolsSupport.ColorResource(name: "TransportBar_SeparatorColor", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "MusicUnderstandingLabLogo" asset catalog image resource.
    static let musicUnderstandingLabLogo = DeveloperToolsSupport.ImageResource(name: "MusicUnderstandingLabLogo", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "Activity_BassColor" asset catalog color.
    static var activityBass: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .activityBass)
#else
        .init()
#endif
    }

    /// The "Activity_DrumColor" asset catalog color.
    static var activityDrum: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .activityDrum)
#else
        .init()
#endif
    }

    /// The "Activity_OtherColor" asset catalog color.
    static var activityOther: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .activityOther)
#else
        .init()
#endif
    }

    /// The "Activity_VocalColor" asset catalog color.
    static var activityVocal: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .activityVocal)
#else
        .init()
#endif
    }

    /// The "Loudness_ValueColor" asset catalog color.
    static var loudnessValue: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .loudnessValue)
#else
        .init()
#endif
    }

    /// The "Pace_ClipBorderColor" asset catalog color.
    static var paceClipBorder: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .paceClipBorder)
#else
        .init()
#endif
    }

    /// The "Pace_ValueColor" asset catalog color.
    static var paceValue: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .paceValue)
#else
        .init()
#endif
    }

    /// The "PlayheadColor" asset catalog color.
    static var playhead: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .playhead)
#else
        .init()
#endif
    }

    /// The "Structure_PhraseColor" asset catalog color.
    static var structurePhrase: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .structurePhrase)
#else
        .init()
#endif
    }

    /// The "Structure_SectionColor" asset catalog color.
    static var structureSection: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .structureSection)
#else
        .init()
#endif
    }

    /// The "Structure_SegmentColor" asset catalog color.
    static var structureSegment: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .structureSegment)
#else
        .init()
#endif
    }

    /// The "Tile_BackgroundColor" asset catalog color.
    static var tileBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tileBackground)
#else
        .init()
#endif
    }

    /// The "TransportBar_BackgroundColor" asset catalog color.
    static var transportBarBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .transportBarBackground)
#else
        .init()
#endif
    }

    /// The "TransportBar_ButtonBackgroundColor" asset catalog color.
    static var transportBarButtonBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .transportBarButtonBackground)
#else
        .init()
#endif
    }

    /// The "TransportBar_SeparatorColor" asset catalog color.
    static var transportBarSeparator: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .transportBarSeparator)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "Activity_BassColor" asset catalog color.
    static var activityBass: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .activityBass)
#else
        .init()
#endif
    }

    /// The "Activity_DrumColor" asset catalog color.
    static var activityDrum: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .activityDrum)
#else
        .init()
#endif
    }

    /// The "Activity_OtherColor" asset catalog color.
    static var activityOther: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .activityOther)
#else
        .init()
#endif
    }

    /// The "Activity_VocalColor" asset catalog color.
    static var activityVocal: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .activityVocal)
#else
        .init()
#endif
    }

    /// The "Loudness_ValueColor" asset catalog color.
    static var loudnessValue: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .loudnessValue)
#else
        .init()
#endif
    }

    /// The "Pace_ClipBorderColor" asset catalog color.
    static var paceClipBorder: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .paceClipBorder)
#else
        .init()
#endif
    }

    /// The "Pace_ValueColor" asset catalog color.
    static var paceValue: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .paceValue)
#else
        .init()
#endif
    }

    /// The "PlayheadColor" asset catalog color.
    static var playhead: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .playhead)
#else
        .init()
#endif
    }

    /// The "Structure_PhraseColor" asset catalog color.
    static var structurePhrase: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .structurePhrase)
#else
        .init()
#endif
    }

    /// The "Structure_SectionColor" asset catalog color.
    static var structureSection: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .structureSection)
#else
        .init()
#endif
    }

    /// The "Structure_SegmentColor" asset catalog color.
    static var structureSegment: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .structureSegment)
#else
        .init()
#endif
    }

    /// The "Tile_BackgroundColor" asset catalog color.
    static var tileBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .tileBackground)
#else
        .init()
#endif
    }

    /// The "TransportBar_BackgroundColor" asset catalog color.
    static var transportBarBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .transportBarBackground)
#else
        .init()
#endif
    }

    /// The "TransportBar_ButtonBackgroundColor" asset catalog color.
    static var transportBarButtonBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .transportBarButtonBackground)
#else
        .init()
#endif
    }

    /// The "TransportBar_SeparatorColor" asset catalog color.
    static var transportBarSeparator: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .transportBarSeparator)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "Activity_BassColor" asset catalog color.
    static var activityBass: SwiftUI.Color { .init(.activityBass) }

    /// The "Activity_DrumColor" asset catalog color.
    static var activityDrum: SwiftUI.Color { .init(.activityDrum) }

    /// The "Activity_OtherColor" asset catalog color.
    static var activityOther: SwiftUI.Color { .init(.activityOther) }

    /// The "Activity_VocalColor" asset catalog color.
    static var activityVocal: SwiftUI.Color { .init(.activityVocal) }

    /// The "Loudness_ValueColor" asset catalog color.
    static var loudnessValue: SwiftUI.Color { .init(.loudnessValue) }

    /// The "Pace_ClipBorderColor" asset catalog color.
    static var paceClipBorder: SwiftUI.Color { .init(.paceClipBorder) }

    /// The "Pace_ValueColor" asset catalog color.
    static var paceValue: SwiftUI.Color { .init(.paceValue) }

    /// The "PlayheadColor" asset catalog color.
    static var playhead: SwiftUI.Color { .init(.playhead) }

    /// The "Structure_PhraseColor" asset catalog color.
    static var structurePhrase: SwiftUI.Color { .init(.structurePhrase) }

    /// The "Structure_SectionColor" asset catalog color.
    static var structureSection: SwiftUI.Color { .init(.structureSection) }

    /// The "Structure_SegmentColor" asset catalog color.
    static var structureSegment: SwiftUI.Color { .init(.structureSegment) }

    /// The "Tile_BackgroundColor" asset catalog color.
    static var tileBackground: SwiftUI.Color { .init(.tileBackground) }

    /// The "TransportBar_BackgroundColor" asset catalog color.
    static var transportBarBackground: SwiftUI.Color { .init(.transportBarBackground) }

    /// The "TransportBar_ButtonBackgroundColor" asset catalog color.
    static var transportBarButtonBackground: SwiftUI.Color { .init(.transportBarButtonBackground) }

    /// The "TransportBar_SeparatorColor" asset catalog color.
    static var transportBarSeparator: SwiftUI.Color { .init(.transportBarSeparator) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "Activity_BassColor" asset catalog color.
    static var activityBass: SwiftUI.Color { .init(.activityBass) }

    /// The "Activity_DrumColor" asset catalog color.
    static var activityDrum: SwiftUI.Color { .init(.activityDrum) }

    /// The "Activity_OtherColor" asset catalog color.
    static var activityOther: SwiftUI.Color { .init(.activityOther) }

    /// The "Activity_VocalColor" asset catalog color.
    static var activityVocal: SwiftUI.Color { .init(.activityVocal) }

    /// The "Loudness_ValueColor" asset catalog color.
    static var loudnessValue: SwiftUI.Color { .init(.loudnessValue) }

    /// The "Pace_ClipBorderColor" asset catalog color.
    static var paceClipBorder: SwiftUI.Color { .init(.paceClipBorder) }

    /// The "Pace_ValueColor" asset catalog color.
    static var paceValue: SwiftUI.Color { .init(.paceValue) }

    /// The "PlayheadColor" asset catalog color.
    static var playhead: SwiftUI.Color { .init(.playhead) }

    /// The "Structure_PhraseColor" asset catalog color.
    static var structurePhrase: SwiftUI.Color { .init(.structurePhrase) }

    /// The "Structure_SectionColor" asset catalog color.
    static var structureSection: SwiftUI.Color { .init(.structureSection) }

    /// The "Structure_SegmentColor" asset catalog color.
    static var structureSegment: SwiftUI.Color { .init(.structureSegment) }

    /// The "Tile_BackgroundColor" asset catalog color.
    static var tileBackground: SwiftUI.Color { .init(.tileBackground) }

    /// The "TransportBar_BackgroundColor" asset catalog color.
    static var transportBarBackground: SwiftUI.Color { .init(.transportBarBackground) }

    /// The "TransportBar_ButtonBackgroundColor" asset catalog color.
    static var transportBarButtonBackground: SwiftUI.Color { .init(.transportBarButtonBackground) }

    /// The "TransportBar_SeparatorColor" asset catalog color.
    static var transportBarSeparator: SwiftUI.Color { .init(.transportBarSeparator) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "MusicUnderstandingLabLogo" asset catalog image.
    static var musicUnderstandingLabLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .musicUnderstandingLabLogo)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "MusicUnderstandingLabLogo" asset catalog image.
    static var musicUnderstandingLabLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .musicUnderstandingLabLogo)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

