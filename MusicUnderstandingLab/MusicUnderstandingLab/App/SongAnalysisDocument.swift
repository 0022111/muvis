/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The file document for exporting analysis results as JSON.
*/
import SwiftUI
import UniformTypeIdentifiers

/// A file document that serializes analysis results to JSON for export.
struct SongAnalysisDocument: FileDocument {

    /// The content types this document can read.
    static var readableContentTypes: [UTType] { [.json] }

    /// The encoded JSON data.
    let data: Data

    /// Creates a document by encoding the analyzer's results as JSON.
    ///
    /// - Parameter analyzer: The analyzer results to encode.
    ///
    /// - Throws: If JSON encoding fails.
    @MainActor init(analyzer: AssetAnalyzer) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        data = try encoder.encode(analyzer.result)
    }

    /// Creates a document by reading data from the given file configuration.
    ///
    /// - Parameter configuration: The read configuration containing the file contents.
    ///
    /// - Throws: If reading the file contents fails.
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadUnknown)
        }
        data = contents
    }

    /// Returns a file wrapper containing the document's JSON data.
    ///
    /// - Parameter configuration: The write configuration for the export.
    ///
    /// - Returns: A file wrapper containing the encoded data.
    ///
    /// - Throws: If creating the file wrapper fails.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
