import Foundation

/// Builds a fully self-contained HTML document from Markdown source by inlining
/// the bundled CSS/JS (marked, highlight.js, DOMPurify). No network or external
/// file access is needed, which keeps the app comfortably inside the App Sandbox.
enum Renderer {
    /// Cached template + asset strings, loaded once from the bundle.
    private static let assets: Assets = Assets.load()

    static func html(for markdown: String) -> String {
        var page = assets.template
        // Order matters: replace the source token last so earlier replacements
        // can't accidentally collide with user content.
        page = page.replacingOccurrences(of: "/*__MARKDOWN_CSS__*/", with: assets.markdownCSS)
        page = page.replacingOccurrences(of: "/*__HLJS_LIGHT_CSS__*/", with: assets.hljsLightCSS)
        page = page.replacingOccurrences(of: "/*__HLJS_DARK_CSS__*/", with: assets.hljsDarkCSS)
        page = page.replacingOccurrences(of: "/*__MARKED_JS__*/", with: assets.markedJS)
        page = page.replacingOccurrences(of: "/*__PURIFY_JS__*/", with: assets.purifyJS)
        page = page.replacingOccurrences(of: "/*__HLJS_JS__*/", with: assets.hljsJS)
        // Inject the markdown as a JSON string literal so quotes/newlines/scripts
        // in the source can't break out of the JS string context.
        page = page.replacingOccurrences(of: "/*__MARKDOWN_SOURCE__*/ \"\"", with: jsString(markdown))
        return page
    }

    /// Encode an arbitrary string as a safe JavaScript string literal.
    private static func jsString(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [s])) ?? Data("[\"\"]".utf8)
        let json = String(decoding: data, as: UTF8.self)
        // JSONSerialization wraps in an array: ["..."] -> strip the brackets.
        let trimmed = json.dropFirst().dropLast()
        return String(trimmed)
    }

    private struct Assets {
        let template: String
        let markdownCSS: String
        let hljsLightCSS: String
        let hljsDarkCSS: String
        let markedJS: String
        let purifyJS: String
        let hljsJS: String

        static func load() -> Assets {
            func read(_ name: String, _ ext: String) -> String {
                guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                      let s = try? String(contentsOf: url, encoding: .utf8) else {
                    assertionFailure("Missing bundled resource: \(name).\(ext)")
                    return ""
                }
                return s
            }
            return Assets(
                template: read("template", "html"),
                markdownCSS: read("markdown", "css"),
                hljsLightCSS: read("hljs-github-light", "css"),
                hljsDarkCSS: read("hljs-github-dark", "css"),
                markedJS: read("marked.min", "js"),
                purifyJS: read("purify.min", "js"),
                hljsJS: read("highlight.min", "js")
            )
        }
    }
}
