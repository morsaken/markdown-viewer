import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        MarkdownWebView(html: Renderer.html(for: document.text))
            .frame(minWidth: 480, minHeight: 360)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView(document: MarkdownDocument(text: "# Hello\n\nThis is **markdown**."))
}
