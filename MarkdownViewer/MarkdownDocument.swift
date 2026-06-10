import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Markdown content type. The system already defines `.markdown` on recent
    /// OSes; we declare our own constant tied to the bundle's exported type so
    /// older callers and the `.mdown`/`.markdown` extensions resolve correctly.
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown")
}

/// A read-only document wrapping the text of a Markdown file.
struct MarkdownDocument: FileDocument {
    var text: String

    init(text: String = "") {
        self.text = text
    }

    /// Types this app can open. `.markdownText` covers .md/.markdown/.mdown;
    /// `.plainText` lets users open arbitrary text files as markdown too.
    static var readableContentTypes: [UTType] {
        [.markdownText, .plainText]
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // Markdown is text; decode UTF-8 with a permissive fallback.
        self.text = String(data: data, encoding: .utf8)
            ?? String(decoding: data, as: UTF8.self)
    }

    /// Viewer is read-only, but FileDocument requires a writer. Round-trip the text.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
