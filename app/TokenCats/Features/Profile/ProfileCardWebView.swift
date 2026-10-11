import SwiftUI
import WebKit

/// Shows a profile card SVG the way GitHub will: through WebKit, so the cats animate and the embedded font loads.
/// (NSImage draws every animation frame at once and ignores the card's font.)
struct ProfileCardWebView: NSViewRepresentable {
    let svg: String

    func makeNSView(context _: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        view.loadHTMLString(ProfileCardPage.html(svg), baseURL: nil)
        return view
    }

    func updateNSView(_: WKWebView, context _: Context) {}
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
