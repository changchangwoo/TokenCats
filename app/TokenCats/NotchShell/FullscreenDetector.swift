import AppKit
import Combine

/// Tells, per display, whether a full-screen app owns it, so the closed notch and its cats get out of the way of
/// a video, a talk or a game. Reads the window list on app switches and every two seconds; each read is a few
/// hundred microseconds. Written for TokenCats: boring.notch used MacroVisionKit for this.
@MainActor
final class FullscreenDetector: ObservableObject {
    static let shared = FullscreenDetector()

    /// Display UUID → a full-screen window covers it.
    @Published private(set) var fullscreenStatus: [String: Bool] = [:]

    private var timer: Timer?
    private var activationObserver: Any?

    private init() {
        refresh()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in FullscreenDetector.shared.refresh() }
        }
        let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in FullscreenDetector.shared.refresh() }
        }
        timer.tolerance = 1
        self.timer = timer
    }

    func refresh() {
        let status = Self.status(windows: Self.normalWindows(), screens: Self.screenRects())
        if status != fullscreenStatus { fullscreenStatus = status }
    }

    /// A display is full-screen when another app's normal-level window covers its whole frame, menu bar included.
    static func status(windows: [CGRect], screens: [(uuid: String, rect: CGRect)]) -> [String: Bool] {
        var status: [String: Bool] = [:]
        for screen in screens {
            status[screen.uuid] = windows.contains { window in
                abs(window.minX - screen.rect.minX) <= 1 && abs(window.minY - screen.rect.minY) <= 1
                    && window.width >= screen.rect.width - 1 && window.height >= screen.rect.height - 1
            }
        }
        return status
    }

    /// On-screen windows at the normal level that belong to other apps, in the window server's coordinates
    /// (origin at the main display's top left).
    private static func normalWindows() -> [CGRect] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? Int32) != ownPID,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"], let width = bounds["Width"], let height = bounds["Height"]
            else { return nil }
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }

    /// Each display's frame in the window server's coordinates (Cocoa frames are flipped and start at the bottom).
    private static func screenRects() -> [(uuid: String, rect: CGRect)] {
        guard let main = NSScreen.screens.first else { return [] }
        let mainHeight = main.frame.height
        return NSScreen.screens.compactMap { screen in
            guard let uuid = screen.displayUUID else { return nil }
            let frame = screen.frame
            return (uuid, CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height))
        }
    }
}
