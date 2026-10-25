import AppKit

/// The borderless window under the menu bar icon. Sized for the tallest tab plus room for the shadow; the visible
/// panel is drawn top-aligned inside it and clicks on the transparent rest pass through to the app below.
final class MenuBarPanel: NSPanel {
    static let size = CGSize(width: windowSize.width + 2 * shadowPadding, height: windowSize.height)

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = .statusBar
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    /// A text field inside (naming a cat) needs the keyboard.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
