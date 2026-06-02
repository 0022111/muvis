/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The main analysis visualization screen showing all musical analysis results.
*/
import CoreMedia
import MusicUnderstanding
import SwiftUI
import UniformTypeIdentifiers

/// The main analysis visualization screen.
struct VisualizationView: View {

    private enum Constants {
        static let videoHeight: CGFloat = 490
        static let separatorHeight: CGFloat = 1
        static let tileSpacing: CGFloat = 12
        static let structureHeight: CGFloat = 100
        static let instrumentRangesHeight: CGFloat = 190
        static let loudnessHeight: CGFloat = 200
        static let paceHeight: CGFloat = 120
        static let activityHeight: CGFloat = 120
        static let smallTileHeight: CGFloat = 100
        static let sectionBarHeight: CGFloat = 14
        static let segmentBarHeight: CGFloat = 11
        static let phraseBarHeight: CGFloat = 9
        static let structureSpacing: CGFloat = 3
        static let showVideoAnimationDuration: Double = 0.4
    }

    @Environment(AssetAnalyzer.self) var analyzer
    @Environment(AssetPlayer.self) var player

    @State private var showVideo = false
    @State private var exportDocument: SongAnalysisDocument?
    @State private var showExporter = false

    var body: some View {
        VStack(spacing: 0) {
            if showVideo {
                VideoView()
                    .frame(height: Constants.videoHeight)
                    .transition(.asymmetric(
                        insertion: .push(from: .top),
                        removal: .push(from: .bottom)
                    ))
            }

            AnalysisTiles()

            TransportBarView()
                .padding()
                .background {
                    Rectangle()
                        .fill(Color(.transportBarBackground))
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color(.transportBarSeparator))
                                .frame(height: Constants.separatorHeight)
                        }
                }
        }
        .toolbar { toolbarContent }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: analyzer.displayName
        ) { _ in
            exportDocument = nil
        }
        .animation(.smooth(duration: Constants.showVideoAnimationDuration), value: showVideo)
    }

    // MARK: - Analysis Tiles

    private struct AnalysisTiles: View {

        @Environment(AssetAnalyzer.self) var analyzer

        var body: some View {
            ScrollView {
                VStack(spacing: Constants.tileSpacing) {
                    HStack(spacing: Constants.tileSpacing) {
                        TileView(title: "Key", height: Constants.smallTileHeight, isLoading: analyzer.key == nil) {
                            if let keySignature = analyzer.key?.ranges.first?.value {
                                KeyView(keySignature: keySignature)
                            }
                        }
                        TileView(title: "Rhythm", height: Constants.smallTileHeight, isLoading: analyzer.rhythm == nil) {
                            if let rhythm = analyzer.rhythm {
                                RhythmView(rhythmResult: rhythm)
                            }
                        }
                    }

                    TileView(title: "Structure", height: Constants.structureHeight, showPlayhead: true, isLoading: analyzer.structure == nil) {
                        if let structure = analyzer.structure {
                            let layers: [(ranges: [CMTimeRange], tint: Color, height: CGFloat)] = [
                                (structure.sections, Color(.structureSection), Constants.sectionBarHeight),
                                (structure.segments, Color(.structureSegment), Constants.segmentBarHeight),
                                (structure.phrases, Color(.structurePhrase), Constants.phraseBarHeight)
                            ]
                            VStack(spacing: Constants.structureSpacing) {
                                ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                                    StructureRoundedBarView(ranges: layer.ranges, tint: layer.tint)
                                        .frame(height: layer.height)
                                }
                            }
                        }
                    }

                    TileView(title: "Pace", height: Constants.paceHeight, showPlayhead: true, isLoading: analyzer.pace == nil) {
                        if let pace = analyzer.pace {
                            PaceView(paceResult: pace)
                        }
                    }

                    TileView(title: "Instrument Ranges",
                             height: Constants.instrumentRangesHeight,
                             showPlayhead: true,
                             isLoading: analyzer.instrumentActivity == nil) {
                        if let activity = analyzer.instrumentActivity {
                            InstrumentRangesView(result: activity)
                        }
                    }

                    ForEach([InstrumentActivityResult.Instrument.vocal, .drum, .bass, .other], id: \.self) { instrument in
                        TileView(title: "\(instrument.rawValue.capitalized) Activity",
                                 height: Constants.activityHeight,
                                 showPlayhead: true,
                                 isLoading: analyzer.instrumentActivity == nil) {
                            if let activity = analyzer.instrumentActivity {
                                InstrumentActivityView(
                                    instrument: instrument,
                                    activity: activity.activity[instrument] ?? []
                                )
                            }
                        }
                    }

                    TileView(title: "Loudness", height: Constants.loudnessHeight, isLoading: analyzer.loudness == nil) {
                        if let loudness = analyzer.loudness {
                            LoudnessView(loudnessResult: loudness)
                        }
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                showVideo.toggle()
            } label: {
                Label("Video", systemImage: showVideo ? "film.fill" : "film")
            }
            .disabled(analyzer.pace == nil || analyzer.structure == nil)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                if let doc = try? SongAnalysisDocument(analyzer: analyzer) {
                    exportDocument = doc
                    showExporter = true
                }
            } label: {
                Label("Export JSON", systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(analyzer.result == nil)
        }
    }
}
