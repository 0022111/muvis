/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The song selection screen for choosing audio files to analyze.
*/
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// Presents the song selection screen.
struct SongSelectionView: View {

    private enum Constants {
        static let logoSize: CGFloat = 256
        static let textBottomPadding: CGFloat = 5
    }

    let onSongSelected: (URL) -> Void

    init(onSongSelected: @escaping (URL) -> Void) {
        self.onSongSelected = onSongSelected
    }

    @State private var isPresented = false

    var body: some View {
        VStack {
            Spacer()

            Image("MusicUnderstandingLabLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.logoSize, height: Constants.logoSize)
                .padding()

            Text("Music Understanding Lab")
                .font(.largeTitle.bold())
                .padding(.bottom, Constants.textBottomPadding)

            Text("Select a song to analyze")
                .foregroundStyle(.secondary)

            Button("Select Song…") {
                isPresented = true
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .padding()

            Spacer()
        }
        .fileImporter(isPresented: $isPresented, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                onSongSelected(url)
            case .failure:
                break
            }
        }
    }
}
