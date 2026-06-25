import SwiftUI
import UniformTypeIdentifiers

@main
struct MarkdownViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document)
        }
        .commands {
            // Custom "About" panel crediting the author.
            CommandGroup(replacing: .appInfo) {
                Button("About Markdown Viewer") {
                    let credits = NSAttributedString(
                        string: "Created by Orhan Polat",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                    )
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
                }
            }
            // Replace the default "New" item set — this app only views documents.
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
