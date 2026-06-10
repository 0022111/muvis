import AppKit
import AudioToolbox
import CoreAudio
import SwiftUI

/// mulive — real-time LUFS meter for Ableton Live.
///
/// Captures Live's audio output with a Core Audio process tap (no routing
/// changes) and computes BS.1770-4 loudness: momentary (400ms), short-term
/// (3s), gated integrated, and sample peak. Floating always-on-top window.
@main
struct MULiveApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup("mulive") {
            MeterView()
        }
        .defaultSize(width: 300, height: 230)
        .windowResizability(.contentSize)
    }
}

// MARK: - BS.1770-4 loudness engine

/// K-weighting biquad (RBJ cookbook, redesigned for the stream's sample rate).
private struct Biquad {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    static func highShelf(fs: Double, f0: Double = 1681.974450955533,
                          gainDB: Double = 3.999843853973347,
                          q: Double = 0.7071752369554196) -> Biquad {
        let A = pow(10, gainDB / 40)
        let w0 = 2 * .pi * f0 / fs
        let alpha = sin(w0) / (2 * q)
        let c = cos(w0)
        let a0 = (A + 1) - (A - 1) * c + 2 * sqrt(A) * alpha
        var f = Biquad()
        f.b0 = (A * ((A + 1) + (A - 1) * c + 2 * sqrt(A) * alpha)) / a0
        f.b1 = (-2 * A * ((A - 1) + (A + 1) * c)) / a0
        f.b2 = (A * ((A + 1) + (A - 1) * c - 2 * sqrt(A) * alpha)) / a0
        f.a1 = (2 * ((A - 1) - (A + 1) * c)) / a0
        f.a2 = ((A + 1) - (A - 1) * c - 2 * sqrt(A) * alpha) / a0
        return f
    }

    static func highPass(fs: Double, f0: Double = 38.13547087602444,
                         q: Double = 0.5003270373238773) -> Biquad {
        let w0 = 2 * .pi * f0 / fs
        let alpha = sin(w0) / (2 * q)
        let c = cos(w0)
        let a0 = 1 + alpha
        var f = Biquad()
        f.b0 = ((1 + c) / 2) / a0
        f.b1 = (-(1 + c)) / a0
        f.b2 = ((1 + c) / 2) / a0
        f.a1 = (-2 * c) / a0
        f.a2 = (1 - alpha) / a0
        return f
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }
}

/// Lock-protected DSP state fed from the Core Audio IO thread.
private final class LoudnessEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var shelf: [Biquad] = []
    private var hp: [Biquad] = []
    private var ring: [Double] = []     // K-weighted squared samples, summed over channels
    private var ringIndex = 0
    private var ringFilled = 0
    private var sampleRate = 48000.0
    private var channels = 2
    private(set) var peak = -Double.infinity
    private var blockEnergies: [Double] = []   // 400ms gating blocks for integrated
    private var samplesSinceBlock = 0

    func configure(sampleRate: Double, channels: Int) {
        lock.lock(); defer { lock.unlock() }
        self.sampleRate = sampleRate
        self.channels = max(1, channels)
        shelf = (0..<self.channels).map { _ in .highShelf(fs: sampleRate) }
        hp = (0..<self.channels).map { _ in .highPass(fs: sampleRate) }
        ring = [Double](repeating: 0, count: Int(sampleRate * 3.0))
        ringIndex = 0
        ringFilled = 0
        samplesSinceBlock = 0
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        peak = -.infinity
        blockEnergies.removeAll()
    }

    /// Feed interleaved float32 frames from the IO callback.
    func feed(_ samples: UnsafePointer<Float>, frames: Int, channels chans: Int) {
        lock.lock(); defer { lock.unlock() }
        guard !ring.isEmpty else { return }
        let n = min(chans, channels)
        let blockSize = Int(sampleRate * 0.1)  // contribute one gating step per 100ms
        for f in 0..<frames {
            var sumSq = 0.0
            for c in 0..<n {
                let x = Double(samples[f * chans + c])
                let absX = abs(x)
                if absX > 0 {
                    let db = 20 * log10(absX)
                    if db > peak { peak = db }
                }
                let w = hp[c].process(shelf[c].process(x))
                sumSq += w * w
            }
            ring[ringIndex] = sumSq
            ringIndex = (ringIndex + 1) % ring.count
            if ringFilled < ring.count { ringFilled += 1 }
            samplesSinceBlock += 1
            if samplesSinceBlock >= blockSize {
                samplesSinceBlock = 0
                if let e = windowEnergy(seconds: 0.4) { blockEnergies.append(e) }
            }
        }
    }

    /// Mean of the most recent `seconds` of squared K-weighted samples.
    private func windowEnergy(seconds: Double) -> Double? {
        let count = min(Int(sampleRate * seconds), ringFilled)
        guard count > 0 else { return nil }
        var sum = 0.0
        var i = (ringIndex - count + ring.count) % ring.count
        for _ in 0..<count {
            sum += ring[i]
            i = (i + 1) % ring.count
        }
        return sum / Double(count)
    }

    private func lufs(_ energy: Double?) -> Double? {
        guard let energy, energy > 0 else { return nil }
        return -0.691 + 10 * log10(energy)
    }

    struct Reading {
        var momentary: Double?
        var shortTerm: Double?
        var integrated: Double?
        var peak: Double?
    }

    func read() -> Reading {
        lock.lock(); defer { lock.unlock() }
        var r = Reading()
        r.momentary = lufs(windowEnergy(seconds: 0.4))
        r.shortTerm = lufs(windowEnergy(seconds: 3.0))
        r.peak = peak.isFinite ? peak : nil

        // BS.1770-4 two-stage gating over 400ms blocks.
        let loud = blockEnergies.compactMap { e -> (Double, Double)? in
            guard let l = lufs(e) else { return nil }
            return l > -70 ? (l, e) : nil
        }
        if !loud.isEmpty {
            let ungated = -0.691 + 10 * log10(loud.map(\.1).reduce(0, +) / Double(loud.count))
            let gate = ungated - 10
            let kept = loud.filter { $0.0 > gate }
            if !kept.isEmpty {
                r.integrated = -0.691 + 10 * log10(kept.map(\.1).reduce(0, +) / Double(kept.count))
            }
        }
        return r
    }
}

// MARK: - Process tap capture

@Observable @MainActor
final class TapController {
    enum State: Equatable {
        case searching
        case running(String)
        case failed(String)
    }

    var state: State = .searching
    var momentary: Double?
    var shortTerm: Double?
    var integrated: Double?
    var peak: Double?

    private let engine = LoudnessEngine()
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProc: AudioDeviceIOProcID?
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func resetIntegrated() {
        engine.reset()
    }

    private func tick() {
        if case .running = state {
            let r = engine.read()
            momentary = r.momentary
            shortTerm = r.shortTerm
            integrated = r.integrated
            peak = r.peak
        } else if case .failed = state {
            // Leave the error up; user can relaunch.
        } else {
            attach()
        }
    }

    private func attach() {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            ($0.bundleIdentifier ?? "").lowercased().contains("ableton")
                || ($0.localizedName ?? "").hasPrefix("Live")
        }) else { return }  // keep searching

        do {
            try startTap(pid: app.processIdentifier)
            state = .running(app.localizedName ?? "Ableton Live")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func startTap(pid: pid_t) throws {
        func check(_ status: OSStatus, _ what: String) throws {
            guard status == noErr else {
                throw NSError(domain: "mulive", code: Int(status),
                              userInfo: [NSLocalizedDescriptionKey: "\(what) failed (\(status))"])
            }
        }

        // PID → audio process object
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var pidValue = pid
        var processObject = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                             UInt32(MemoryLayout<pid_t>.size), &pidValue,
                                             &size, &processObject),
                  "PID translation")

        // Tap on the process (stereo mixdown of everything it plays)
        let description = CATapDescription(stereoMixdownOfProcesses: [processObject])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID), "tap creation")

        // Tap stream format
        var format = AudioStreamBasicDescription()
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &size, &format),
                  "tap format read")
        engine.configure(sampleRate: format.mSampleRate,
                         channels: Int(format.mChannelsPerFrame))

        // Aggregate device hosting the tap
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "mulive tap",
            kAudioAggregateDeviceUIDKey as String: "mulive-" + UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceIsStackedKey as String: false,
            kAudioAggregateDeviceTapAutoStartKey as String: true,
            kAudioAggregateDeviceSubDeviceListKey as String: [Any](),
            kAudioAggregateDeviceTapListKey as String: [
                [kAudioSubTapUIDKey as String: description.uuid.uuidString]
            ],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary,
                                                     &aggregateID),
                  "aggregate device creation")

        let engine = self.engine
        try check(AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregateID, nil) {
            _, inputData, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: inputData))
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let channelCount = Int(buffer.mNumberChannels)
                let frames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / max(1, channelCount)
                engine.feed(data.assumingMemoryBound(to: Float.self),
                            frames: frames, channels: channelCount)
            }
        }, "IO proc creation")

        try check(AudioDeviceStart(aggregateID, ioProc), "device start")
    }
}

// MARK: - UI

struct MeterView: View {
    @State private var controller = TapController()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch controller.state {
            case .searching:
                Label("waiting for Ableton Live…", systemImage: "waveform.badge.magnifyingglass")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .running(let name):
                HStack {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(name).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset") { controller.resetIntegrated() }
                        .controlSize(.small)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(format(controller.momentary))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("M").font(.headline).foregroundStyle(.secondary)
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
                    GridRow {
                        Text("Short-term").foregroundStyle(.secondary)
                        Text(format(controller.shortTerm)).monospacedDigit()
                    }
                    GridRow {
                        Text("Integrated").foregroundStyle(.secondary)
                        Text(format(controller.integrated)).monospacedDigit()
                    }
                    GridRow {
                        Text("Peak").foregroundStyle(.secondary)
                        Text(format(controller.peak, suffix: " dB")).monospacedDigit()
                    }
                }
                .font(.system(size: 13))
            }
        }
        .padding(14)
        .frame(width: 280, height: 200, alignment: .topLeading)
        .onAppear {
            controller.start()
            for window in NSApp.windows {
                window.level = .floating
            }
        }
    }

    private func format(_ value: Double?, suffix: String = "") -> String {
        guard let value, value.isFinite, value > -99 else { return "–" }
        return String(format: "%.1f%@", value, suffix)
    }
}
