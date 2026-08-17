import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument

    private var defaultHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return screenHeight * 0.75
    }

    var body: some View {
        MarkdownWebView(html: Renderer.html(for: document.text))
            .frame(minWidth: 480, idealWidth: 800, minHeight: 360, idealHeight: defaultHeight)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView(document: MarkdownDocument(text: "# Hello\n\nThis is **markdown**."))
}
