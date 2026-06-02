/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A reusable card container with a title, optional playhead, and loading state.
*/
import SwiftUI

private enum Constants {
    static let headerTextSpacing: CGFloat = 2
    static let headerPadding: CGFloat = 10
    static let contentBottomPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 12
}

/// A reusable card container with a title, optional subtitle, optional playhead, and loading state.
struct TileView<Content: View>: View {

    /// The title displayed at the top of the tile.
    let title: String

    /// An optional subtitle displayed below the title.
    var subtitle: String?

    /// The fixed height of the tile content area, if constrained.
    var height: CGFloat?

    /// Whether to overlay a playhead on the content area.
    var showPlayhead: Bool = false

    /// Whether to show a loading indicator over the content.
    var isLoading: Bool = false

    /// The content view displayed inside the tile.
    @ViewBuilder let content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Constants.headerTextSpacing) {
                Text(title)
                    .font(sizeClass == .regular ? .title3.bold() : .headline)

                if let subtitle {
                    Text(subtitle)
                        .font(sizeClass == .regular ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Constants.headerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)

            content
                .clipped()
                .overlay {
                    if showPlayhead {
                        PlayheadView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Constants.contentBottomPadding)

            if height != nil {
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(Color(.tileBackground))
        )
        .accessibilityElement(children: .combine)
    }
}
