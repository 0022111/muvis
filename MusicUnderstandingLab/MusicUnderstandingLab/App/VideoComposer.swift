/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The video composition builder that sequences clips to match song structure and pace.
*/
@preconcurrency import AVFoundation
import MusicUnderstanding

/// Builds a video composition by sequencing clips across song sections and adjusting clip timing to match the song's pace.
struct VideoComposer: Sendable {

    /// The URL of the song's audio file.
    let songURL: URL

    private let sections: [CMTimeRange]
    private let paceRanges: [MusicUnderstandingSession.RangedValue<Double>]

    /// Creates a video composer for the given song analysis data.
    ///
    /// - Parameter paceRanges: Pace values with associated time ranges.
    /// - Parameter sections: Structural sections of the song.
    /// - Parameter songURL: The URL of the song's audio file.
    init(paceRanges: [MusicUnderstandingSession.RangedValue<Double>],
         sections: [CMTimeRange],
         songURL: URL) {
        self.paceRanges = paceRanges
        self.sections = sections
        self.songURL = songURL
    }

    /// Returns the duration of a single visual clip at the given time in the song.
    ///
    /// Pace describes an event per minute rate. Converting that rate into a
    /// duration indicates how long each clip lasts on screen:
    ///
    ///     duration = 60 seconds / pace (events per minute)
    ///
    private func clipDuration(for time: CMTime) -> Double {
        guard let activePace = paceRanges.last(where: { time >= $0.range.start }) else {
            return 2.0 // Default: 30 events/min → 2-second clips
        }

        let eventsPerMinute = max(activePace.value, 1.0)
        let secondsPerEvent = 60.0 / eventsPerMinute
        return secondsPerEvent
    }

    /// Returns clip durations for a section of music, based on the song's pace.
    ///
    private func clipDurations(for sectionRange: CMTimeRange) -> [Double] {
        let sectionDuration = sectionRange.duration.seconds
        let perClipDuration = clipDuration(for: sectionRange.start)
        let clipCount = max(Int(sectionDuration / perClipDuration), 1)
        let remainder = sectionDuration - Double(clipCount) * perClipDuration

        if remainder < perClipDuration / 2 {
            // Remainder is short — absorb it into the last clip.
            var durations = [Double](repeating: perClipDuration, count: clipCount - 1)
            durations.append(perClipDuration + remainder)
            return durations
        } else {
            // Remainder is long enough to stand on its own.
            var durations = [Double](repeating: perClipDuration, count: clipCount)
            durations.append(remainder)
            return durations
        }
    }

    /// Builds a composed asset with video clips timed to the song's pace.
    ///
    /// - Returns: The composed `AVAsset`, or `nil` if no clips are available.
    /// - Throws: If loading asset tracks or durations fails, or if the task is cancelled.
    func compose() async throws -> AVAsset? {
        let soundtrack = AVURLAsset(url: songURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let soundtrackDuration = try await soundtrack.load(.duration)
        guard let soundtrackAudioTrack = try await soundtrack.loadTracks(withMediaType: .audio).first else { return nil }
        let sampleRate = try await soundtrackAudioTrack.load(.naturalTimeScale)

        let clips = assets()
        guard !clips.isEmpty else { return nil }

        let composition = AVMutableComposition()
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return nil }

        var currentTime = CMTime.zero
        var lastAssetURL: URL?

        for (sectionIndex, sectionRange) in sections.enumerated() {
            if sectionRange.start > soundtrackDuration { break }

            if sectionIndex == 0 && sectionRange.start > currentTime {
                currentTime = sectionRange.start
            }

            let isLastSection = sectionIndex == sections.count - 1
            let sectionSeconds = isLastSection
                ? (soundtrackDuration - sectionRange.start).seconds
                : (sections[sectionIndex + 1].start - sectionRange.start).seconds
            guard sectionSeconds > 0 else { continue }

            let sectionDuration = CMTime(seconds: sectionSeconds, preferredTimescale: sampleRate)
            let effectiveSectionRange = CMTimeRange(start: sectionRange.start,
                                                    duration: sectionDuration)

            for clipDurationInSeconds in clipDurations(for: effectiveSectionRange) {
                guard let asset = nextAsset(from: clips, lastURL: &lastAssetURL),
                      let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }

                let clipDuration = CMTime(seconds: clipDurationInSeconds, preferredTimescale: sampleRate)
                let sourceTimeRange = try await sourceTrack.load(.timeRange)

                try videoTrack.insertTimeRange(
                    CMTimeRange(start: sourceTimeRange.start, duration: sourceTimeRange.duration),
                    of: sourceTrack, at: currentTime
                )
                videoTrack.scaleTimeRange(
                    CMTimeRange(start: currentTime, duration: sourceTimeRange.duration),
                    toDuration: clipDuration
                )

                currentTime = currentTime + clipDuration
            }
        }

        try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: soundtrackDuration), of: soundtrackAudioTrack, at: .zero)

        return composition
    }

    private func nextAsset(from assets: [AVURLAsset], lastURL: inout URL?) -> AVURLAsset? {
        guard !assets.isEmpty else { return nil }
        let candidates = assets.filter { $0.url != lastURL }
        let pick = candidates.randomElement() ?? assets[0]
        lastURL = pick.url
        return pick
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    private func assets() -> [AVURLAsset] {
        guard let directoryURL = Bundle.main.url(forResource: "Video", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { Self.videoExtensions.contains($0.pathExtension.lowercased()) }
            .map { AVURLAsset(url: $0, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]) }
    }
}
