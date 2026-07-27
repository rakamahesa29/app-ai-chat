import SwiftUI
import WebKit

/// WKWebView subclass that forwards scroll events to next responder
/// so the parent SwiftUI ScrollView handles scrolling naturally.
/// Text selection, right-click copy, and all other interactions remain intact.
class NoScrollWKWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

/// Renders Markdown as HTML in a NoScrollWKWebView with Hermes light theme styling.
/// Auto-sizes height to fit content — no internal scrolling.
struct MarkdownWebView: NSViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    /// Global cache of resolved heights keyed by HTML hash. Prevents the
    /// "pop-in" flicker that used to happen when a streaming reply finished:
    /// the streamingBubble is torn down and the messageRow mounts a *new*
    /// WebView that would otherwise start at the default 40pt before its
    /// async height measurement lands. With the cache, re-mounts use the
    /// last-known height for identical HTML.
    private static var heightCache: [Int: CGFloat] = [:]
    private static let heightCacheQueue = DispatchQueue(label: "MarkdownWebView.heightCache")

    static func cachedHeight(for html: String) -> CGFloat? {
        heightCacheQueue.sync { heightCache[html.hashValue] }
    }

    static func storeHeight(_ h: CGFloat, for html: String) {
        heightCacheQueue.async { heightCache[html.hashValue] = h }
    }

    init(html: String, contentHeight: Binding<CGFloat> = .constant(40)) {
        self.html = html
        self._contentHeight = contentHeight
    }
    
    // MARK: - HTML Template
    
    static func fullHTML(_ bodyHTML: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root {
            --bg: #FAFAFA; --surface: #FFFFFF; --text: #111827; --text-secondary: #374151;
            --muted: #6B7280; --accent: #6366F1; --accent-soft: #EEF2FF; --border: #E5E7EB;
            --card: #F9FAFB; --code-bg: #F3F4F6;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --bg: #141414; --surface: #1C1C1E; --text: #F9FAFB; --text-secondary: #E5E7EB;
                --muted: #9CA3AF; --accent: #818CF8; --accent-soft: #1E1B4B; --border: #38383A;
                --card: #242426; --code-bg: #2C2C2E;
            }
        }
        html { overflow: hidden; }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Inter', sans-serif;
            font-size: 14px; line-height: 1.65; color: var(--text);
            background: transparent; padding: 0; word-wrap: break-word;
            -webkit-text-size-adjust: 100%; overflow: hidden;
        }
        h1 { font-size: 1.4em; font-weight: 700; margin: 0.6em 0 0.3em; }
        h2 { font-size: 1.2em; font-weight: 600; margin: 0.5em 0 0.25em; }
        h3 { font-size: 1.05em; font-weight: 600; margin: 0.4em 0 0.2em; }
        p { margin: 0.35em 0; }
        strong { font-weight: 600; }
        ul, ol { margin: 0.35em 0; padding-left: 1.6em; }
        li { margin: 0.12em 0; }
        hr { border: none; height: 1px; background: var(--border); margin: 0.7em 0; }
        code {
            font-family: 'SF Mono', 'Menlo', monospace; font-size: 0.9em;
            background: var(--code-bg); padding: 0.12em 0.4em; border-radius: 4px; color: var(--accent);
        }
        pre {
            background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px;
            padding: 12px 14px; margin: 0.5em 0; overflow-x: auto; font-size: 0.85em; line-height: 1.5;
        }
        pre code { background: none; padding: 0; color: var(--text-secondary); }
        table { width: 100%; border-collapse: collapse; margin: 0.6em 0; font-size: 0.9em; }
        th, td { border: 1px solid var(--border); padding: 7px 12px; text-align: left; }
        th { background: var(--card); font-weight: 600; }
        td { color: var(--text-secondary); }
        tr:nth-child(even) td { background: var(--card); }
        blockquote {
            border-left: 3px solid var(--accent); padding-left: 12px; margin: 0.5em 0;
            color: var(--muted); background: var(--accent-soft); padding: 8px 12px; border-radius: 0 6px 6px 0;
        }
        a { color: var(--accent); text-decoration: none; }
        </style>
        </head>
        <body>\(bodyHTML)</body>
        </html>
        """
    }
    
    // MARK: - macOS
    
    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }
    
    func makeNSView(context: Context) -> NoScrollWKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = NoScrollWKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }
    
    func updateNSView(_ webView: NoScrollWKWebView, context: Context) {
        if context.coordinator.lastHTML == html { return }
        context.coordinator.lastHTML = html

        // Debounce rapid streaming updates so WKWebView has time to finish
        // each load. Without this, loadHTMLString gets called 20-100×/sec
        // during SSE streaming; WKWebView cancels the pending load on each
        // call and never renders anything — the user sees a blank bubble.
        context.coordinator.pendingHTML = html
        context.coordinator.loadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak webView] in
            guard let wv = webView else { return }
            wv.loadHTMLString(Self.fullHTML(html), baseURL: nil)
        }
        context.coordinator.loadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var contentHeight: CGFloat
        var lastHTML: String?
        var pendingHTML: String?
        var loadWorkItem: DispatchWorkItem?
        weak var webView: WKWebView?

        init(contentHeight: Binding<CGFloat>) { self._contentHeight = contentHeight }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self, let h = result as? CGFloat, h > 0 else { return }
                let html = self.lastHTML ?? ""
                DispatchQueue.main.async {
                    // Only push updates when the delta is meaningful — otherwise
                    // sub-pixel jitter from font metrics causes tiny re-layout
                    // loops that read as flicker to the eye.
                    if abs(self.contentHeight - h) > 0.5 {
                        self.contentHeight = h
                    }
                    if !html.isEmpty {
                        MarkdownWebView.storeHeight(h, for: html)
                    }
                }
            }
        }
    }
}

#if os(iOS)
extension MarkdownWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.scrollView.isScrollEnabled = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: container.topAnchor),
            wv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        context.coordinator.webView = wv
        return container
    }
    func updateUIView(_ container: UIView, context: Context) {
        guard let wv = context.coordinator.webView else { return }
        if context.coordinator.lastHTML == html { return }
        context.coordinator.lastHTML = html

        context.coordinator.pendingHTML = html
        context.coordinator.loadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak wv] in
            guard let wv else { return }
            wv.loadHTMLString(Self.fullHTML(html), baseURL: nil)
        }
        context.coordinator.loadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
}
#endif
