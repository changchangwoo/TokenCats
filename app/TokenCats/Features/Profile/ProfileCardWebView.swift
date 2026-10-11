import SwiftUI
import WebKit

/// Shows a profile card SVG the way GitHub will: through WebKit, so the cats animate and the embedded font loads.
/// (NSImage draws every animation frame at once and ignores the card's font.)
struct ProfileCardWebView: NSViewRepresentable {
    let svg: String
    /// Runs once the card is on screen, so a placeholder over it can be lifted.
    var onDraw: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(onDraw: onDraw) }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        context.coordinator.load(svg, into: view)
        return view
    }

    /// A new card (other options, a connected owner) replaces the page; the same card is left alone.
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onDraw = onDraw
        if context.coordinator.svg != svg { context.coordinator.load(svg, into: view) }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onDraw: () -> Void
        private(set) var svg = ""

        init(onDraw: @escaping () -> Void) { self.onDraw = onDraw }

        func load(_ svg: String, into view: WKWebView) {
            self.svg = svg
            view.loadHTMLString(ProfileCardPage.html(svg), baseURL: nil)
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            // A beat for the embedded font, as the snapshot waits.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [onDraw] in onDraw() }
        }
    }
}

enum ProfileCardPage {
    /// The card scaled to the view's width, nothing around it.
    static func html(_ svg: String) -> String {
        "<!doctype html><meta name=viewport content='width=device-width'>"
            + "<style>html,body{margin:0;background:transparent;overflow:hidden}svg{display:block;width:100%;height:auto}</style>"
            + svg
    }

    /// A still picture of the card's first frame at `width` points (for the design snapshots).
    @MainActor
    static func snapshot(_ svg: String, width: CGFloat = 840) async -> NSImage? {
        let height = width * 504 / 840
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        let loaded = Loader()
        view.navigationDelegate = loaded
        view.loadHTMLString(html(svg), baseURL: nil)
        await loaded.wait()
        try? await Task.sleep(for: .milliseconds(300))  // the embedded font
        return try? await view.takeSnapshot(configuration: nil)
    }

    private final class Loader: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var done = false

        @MainActor func wait() async {
            if done { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) { finish() }
        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) { finish() }

        private func finish() {
            done = true
            continuation?.resume()
            continuation = nil
        }
    }
}
