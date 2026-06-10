#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.example.apple-samplecode.MusicUnderstandingLab";

/// The "Activity_BassColor" asset catalog color resource.
static NSString * const ACColorNameActivityBassColor AC_SWIFT_PRIVATE = @"Activity_BassColor";

/// The "Activity_DrumColor" asset catalog color resource.
static NSString * const ACColorNameActivityDrumColor AC_SWIFT_PRIVATE = @"Activity_DrumColor";

/// The "Activity_OtherColor" asset catalog color resource.
static NSString * const ACColorNameActivityOtherColor AC_SWIFT_PRIVATE = @"Activity_OtherColor";

/// The "Activity_VocalColor" asset catalog color resource.
static NSString * const ACColorNameActivityVocalColor AC_SWIFT_PRIVATE = @"Activity_VocalColor";

/// The "Loudness_ValueColor" asset catalog color resource.
static NSString * const ACColorNameLoudnessValueColor AC_SWIFT_PRIVATE = @"Loudness_ValueColor";

/// The "Pace_ClipBorderColor" asset catalog color resource.
static NSString * const ACColorNamePaceClipBorderColor AC_SWIFT_PRIVATE = @"Pace_ClipBorderColor";

/// The "Pace_ValueColor" asset catalog color resource.
static NSString * const ACColorNamePaceValueColor AC_SWIFT_PRIVATE = @"Pace_ValueColor";

/// The "PlayheadColor" asset catalog color resource.
static NSString * const ACColorNamePlayheadColor AC_SWIFT_PRIVATE = @"PlayheadColor";

/// The "Structure_PhraseColor" asset catalog color resource.
static NSString * const ACColorNameStructurePhraseColor AC_SWIFT_PRIVATE = @"Structure_PhraseColor";

/// The "Structure_SectionColor" asset catalog color resource.
static NSString * const ACColorNameStructureSectionColor AC_SWIFT_PRIVATE = @"Structure_SectionColor";

/// The "Structure_SegmentColor" asset catalog color resource.
static NSString * const ACColorNameStructureSegmentColor AC_SWIFT_PRIVATE = @"Structure_SegmentColor";

/// The "Tile_BackgroundColor" asset catalog color resource.
static NSString * const ACColorNameTileBackgroundColor AC_SWIFT_PRIVATE = @"Tile_BackgroundColor";

/// The "TransportBar_BackgroundColor" asset catalog color resource.
static NSString * const ACColorNameTransportBarBackgroundColor AC_SWIFT_PRIVATE = @"TransportBar_BackgroundColor";

/// The "TransportBar_ButtonBackgroundColor" asset catalog color resource.
static NSString * const ACColorNameTransportBarButtonBackgroundColor AC_SWIFT_PRIVATE = @"TransportBar_ButtonBackgroundColor";

/// The "TransportBar_SeparatorColor" asset catalog color resource.
static NSString * const ACColorNameTransportBarSeparatorColor AC_SWIFT_PRIVATE = @"TransportBar_SeparatorColor";

/// The "MusicUnderstandingLabLogo" asset catalog image resource.
static NSString * const ACImageNameMusicUnderstandingLabLogo AC_SWIFT_PRIVATE = @"MusicUnderstandingLabLogo";

#undef AC_SWIFT_PRIVATE
