# MusicUnderstanding Framework

> **Beta** — iOS 27.0+ · iPadOS 27.0+ · Mac Catalyst 27.0+ · macOS 27.0+ · tvOS 27.0+ · visionOS 27.0+ · watchOS 27.0+

Analyze audio content and extract music information: rhythm, pace, loudness, key, structure, and instrument activity.

---

## Overview

Create a `MusicUnderstandingSession`, specify which analyses to run, and receive results either as a single aggregate (`SessionResult`) or as a livestream of partial results.

**Audio input — two modes:**
- **File-based:** `AVAsset` — analyzes a complete audio track
- **Stream-based:** `AsyncSequence<AVReadOnlyAudioPCMBuffer>` — analyzes audio buffers in real time

Loudness supports incremental delivery via `loudnessResults` while analysis is in progress. Call `cancel()` to stop.

---

## API Tree

```
MusicUnderstanding
├── actor MusicUnderstandingSession
│   ├── init(audioProvider:)          — streaming input
│   ├── init(asset:)                  — file-based input
│   ├── func analyze() -> SessionResult
│   ├── func analyze(for: Set<AnalysisType>) -> SessionResult
│   ├── var loudnessResults           — AsyncSequence<LoudnessResult> (incremental)
│   ├── func cancel()
│   │
│   ├── struct SessionResult
│   │   ├── let rhythm: RhythmResult?
│   │   ├── let key: KeyResult?
│   │   ├── let loudness: LoudnessResult?
│   │   ├── let pace: PaceResult?
│   │   ├── let structure: StructureResult?
│   │   └── let instrumentActivity: InstrumentActivityResult?
│   │
│   ├── struct TimedValue<Value>       — value at a CMTime point
│   │   ├── let time: CMTime
│   │   └── let value: Value
│   │
│   └── struct RangedValue<Value>      — value over a CMTimeRange span
│       ├── let range: CMTimeRange
│       └── let value: Value
│
├── struct AnalysisType               — options for analyze(for:)
│   ├── static let rhythm
│   ├── static let key
│   ├── static let loudness
│   ├── static let pace
│   ├── static let structure
│   ├── static let instrumentActivity
│   └── let rawValue: String
│
├── Result Types
│   ├── struct RhythmResult
│   │   ├── let beats: [CMTime]
│   │   ├── let bars: [CMTime]
│   │   └── let beatsPerMinute: Float?
│   │
│   ├── struct KeyResult
│   │   ├── let tonic: KeyResult.Tonic
│   │   ├── let mode: KeyResult.Mode
│   │   └── let ranges: [RangedValue<KeyResult.KeySignature>]
│   │   ├── enum Tonic (@frozen)
│   │   │   └── cases: a, aFlat, aSharp, b, bFlat, c, cSharp,
│   │   │           d, dFlat, dSharp, e, eFlat, f, fSharp,
│   │   │           g, gFlat, gSharp
│   │   ├── enum Mode
│   │   │   └── cases: major, minor
│   │   └── struct KeySignature
│   │       └── (sharp/flat symbols for notes)
│   │
│   ├── struct LoudnessResult          — ITU-R BS.1770 / LUFS
│   │   ├── let integrated: TimedValue<Float>    — full-song LUFS
│   │   ├── let shortTerm: [TimedValue<Float>]   — sampled LUFS across song
│   │   ├── let momentary: [TimedValue<Float>]   — sampled LUFS across song
│   │   └── let peak: TimedValue<Float>          — peak amplitude in dB
│   │   NOTE: in streaming (loudnessResults), momentary/shortTerm each have
│   │         exactly one value representing that moment in time.
│   │
│   ├── struct PaceResult
│   │   └── let ranges: [RangedValue<Double>]    — perceptual events-per-minute
│   │   NOTE: perceptual energy independent of BPM. High-BPM sparse breakdown
│   │         → lower Pace value.
│   │
│   ├── struct StructureResult
│   │   ├── let sections: [CMTimeRange]   — intro, verse, chorus, etc.
│   │   ├── let segments: [CMTimeRange]   — subdivisions of sections
│   │   └── let phrases: [CMTimeRange]    — subdivisions of segments
│   │   Hierarchy: section > segment > phrase
│   │
│   └── struct InstrumentActivityResult
│       ├── let activity: [Instrument : [TimedValue<Float>]]   — 0.0–1.0 continuous
│       ├── let ranges: [Instrument : [CMTimeRange]]           — discrete active windows
│       └── struct Instrument
│           ├── static let vocal
│           ├── static let drum
│           ├── static let bass
│           ├── static let other    — anything not in above three
│           └── let rawValue: String
│
└── enum MusicUnderstandingError
    ├── case emptyAnalysisSet     — analyze(for:) called with empty set
    ├── case invalidAsset         — session initialized with invalid AVAsset
    ├── case sessionInProgress    — analyze() called while already running
    └── case internalError        — unexpected internal failure
```

---

## Analysis Types Reference

| Type | Result Struct | Time Model | Notes |
|------|--------------|------------|-------|
| `.rhythm` | `RhythmResult` | `[CMTime]` arrays | Beat/bar timestamps + BPM |
| `.key` | `KeyResult` | `[RangedValue<KeySignature>]` | Tonic + mode per segment |
| `.loudness` | `LoudnessResult` | `[TimedValue<Float>]` | LUFS + dB peak; streams incrementally |
| `.pace` | `PaceResult` | `[RangedValue<Double>]` | Perceptual EPM, tempo-independent |
| `.structure` | `StructureResult` | `[CMTimeRange]` arrays | 3-level: section > segment > phrase |
| `.instrumentActivity` | `InstrumentActivityResult` | `[TimedValue<Float>]` + `[CMTimeRange]` | 4 categories: vocal, drum, bass, other |

---

## Supported Tonic Notes

`A, A♭, A♯, B♭, B, C, C♯, D♭, D, D♯, E♭, E, F, F♯, G, G♭, G♯`

Enharmonic equivalents (e.g. A♯ vs B♭) are represented as **distinct cases** to preserve original spelling.

---

## Usage Pattern

```swift
// File-based
let session = try await MusicUnderstandingSession(asset: myAVAsset)
let result = try await session.analyze(for: [.rhythm, .key, .loudness])

// result.rhythm?.beats     → [CMTime]
// result.rhythm?.beatsPerMinute → Float?
// result.key?.tonic        → KeyResult.Tonic
// result.key?.mode         → .major / .minor
// result.loudness?.integrated.value → Float (LUFS)

// Streaming
let session = MusicUnderstandingSession(audioProvider: myAsyncSequence)
for try await loudness in session.loudnessResults {
    // each loudness.momentary has exactly one TimedValue
}
```

---

## Protocol Conformances Summary

| Type | Key Conformances |
|------|-----------------|
| `MusicUnderstandingSession` | `Actor`, `Sendable` |
| `SessionResult` | `Codable`, `Sendable` |
| `RhythmResult` | `Codable`, `Sendable` |
| `KeyResult` | `Codable`, `Sendable` |
| `KeyResult.Tonic` | `@frozen`, `Codable`, `Hashable`, `RawRepresentable` |
| `KeyResult.Mode` | `Codable`, `Hashable`, `RawRepresentable` |
| `LoudnessResult` | `Codable`, `Sendable` |
| `PaceResult` | `Codable`, `Sendable` |
| `StructureResult` | `Codable`, `Sendable` |
| `InstrumentActivityResult` | `Codable`, `Sendable` |
| `InstrumentActivityResult.Instrument` | `CodingKeyRepresentable`, `Hashable` |
| `TimedValue<V>` | `Codable`, `Equatable`, `Sendable` |
| `RangedValue<V>` | `Codable`, `Equatable`, `Sendable` |
| `AnalysisType` | `Codable`, `Hashable`, `Sendable` |
| `MusicUnderstandingError` | `Error`, `Equatable`, `Hashable`, `Sendable` |

---

> **Beta Software** — Preliminary API, subject to change. Test with final OS software before shipping.
> Source: [Apple Developer Documentation](https://developer.apple.com/documentation/MusicUnderstanding)
