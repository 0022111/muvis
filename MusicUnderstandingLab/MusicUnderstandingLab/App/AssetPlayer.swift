/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The audio playback controller for the sample app.
*/
@preconcurrency import AVFoundation
import CoreMedia

/// Manages audio playback
@Observable @MainActor
final class AssetPlayer {

    /// The underlying AVPlayer instance.
    let player = AVPlayer()

    /// Whether the player is currently playing.
    private(set) var isPlaying: Bool = false

    /// Current playback position in seconds.
    private(set) var currentTime: Double = 0

    /// Duration of the current item in seconds.
    private(set) var duration: Double = 0

    /// The audio sample rate of the loaded asset, suitable for use as a `CMTimeScale`.
    private(set) var sampleRate: CMTimeScale = 44_100

    /// Current volume of the player, from 0.0 (silent) to 1.0 (full).
    var volume: Float = 1.0 {
        didSet { player.volume = volume }
    }

    private var endOfPlaybackTask: Task<Void, Never>?
    @ObservationIgnored private var timeObserver: Any?

    isolated deinit {
        endOfPlaybackTask?.cancel()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    // MARK: - Public

    /// Creates a new asset player and installs a periodic time observer.
    init() {
        installTimeObserver()
    }

    /// Loads a new player item, optionally preserving the current playback state.
    ///
    /// - Parameter item: The player item to load.
    /// - Parameter preservePlayback: When `true`, maintains the current position and play/pause state.
    func load(_ item: AVPlayerItem, preservePlayback: Bool = false) async {
        let wasPlaying = isPlaying
        let time = player.currentTime()

        replaceItem(item)

        if preservePlayback {
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            if wasPlaying { player.play() }
        }

        async let durationLoad = item.asset.load(.duration)
        async let tracksLoad = item.asset.loadTracks(withMediaType: .audio)

        if let assetDuration = try? await durationLoad, assetDuration.isNumeric {
            duration = assetDuration.seconds
        }

        // Load the audio sample rate from the asset's first audio track.
        if let audioTrack = try? await tracksLoad.first,
           let formatDescription = try? await audioTrack.load(.formatDescriptions).first,
           let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
            sampleRate = CMTimeScale(audioStreamBasicDescription.pointee.mSampleRate)
        }
    }

    /// Starts playback.
    func play() {
        player.play()
        isPlaying = true
    }

    /// Pauses playback.
    func pause() {
        player.pause()
        isPlaying = false
    }

    /// Toggles between playing and paused states.
    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }

    /// Stops playback and seeks back to the beginning.
    func stop() {
        pause()
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = 0
    }

    /// Seeks to the specified time.
    ///
    /// - Parameter time: The target time to seek to.
    func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Private

    private func replaceItem(_ item: AVPlayerItem) {
        player.replaceCurrentItem(with: item)
        observeEndOfPlayback(for: item)
    }

    private func observeEndOfPlayback(for item: AVPlayerItem) {
        endOfPlaybackTask?.cancel()
        endOfPlaybackTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.didPlayToEndTimeNotification, object: item) {
                guard let self else { continue }
                self.pause()
                await self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                self.currentTime = 0
            }
        }
    }

    /// The current playback time formatted as `MM:SS`.
    var formattedCurrentTime: String {
        guard currentTime.isFinite, currentTime >= 0 else { return "00:00" }
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func installTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: sampleRate) // 100ms
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = seconds
                self.isPlaying = self.player.rate != 0
            }
        }
    }
}
