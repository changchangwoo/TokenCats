import AppKit
import Combine
import Defaults

/// The borderless window under the menu bar icon. It never changes size: it is as tall as the tallest tab, the
/// visible panel is drawn top-aligned inside it and grows or shrinks downward only, so its top edge stays put. The
/// transparent rest lets clicks through, and the system shadow follows the visible panel's shape.
final class MenuBarPanel: NSPanel {
    static let size = CGSize(width: openNotchSize.width, height: windowSize.height)

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        isReleasedWhenClosed = false
        level = .statusBar
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        // The controller decides when the panel goes away; AppKit hiding it on deactivate would leave the two out
        // of step.
        hidesOnDeactivate = false
        sharingObserver = Defaults.publisher(.hideFromScreenRecording)
            .sink { [weak self] change in self?.sharingType = change.newValue ? .none : .readWrite }
    }

    private var sharingObserver: AnyCancellable?

    /// A text field inside (naming a cat) needs the keyboard.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
