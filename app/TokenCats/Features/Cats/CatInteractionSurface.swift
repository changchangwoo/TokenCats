import AppKit
import SwiftUI

/// One entry of the room's right-click menu.
struct RoomMenuItem {
    let title: String
    let action: () -> Void
}

/// Native hit regions, one per cat, so macOS owns the pointing-hand cursor and mouse dragging.
struct CatInteractionSurface: NSViewRepresentable {
    let catHitRects: [CGRect]
    let onPetStart: (RoomPoint) -> Void
    let onPetMove: (RoomPoint) -> Void
    let onPetEnd: () -> Void
    /// The pointer's room position while it is over the surface; nil once it leaves.
    let onHover: (RoomPoint?) -> Void
    /// Menu for a right-click (or control-click) at the point; empty for none.
    let contextMenu: (RoomPoint) -> [RoomMenuItem]

    func makeNSView(context: Context) -> CatInteractionNSView { CatInteractionNSView() }

    func updateNSView(_ view: CatInteractionNSView, context: Context) {
        view.onPetStart = onPetStart
        view.onPetMove = onPetMove
        view.onPetEnd = onPetEnd
        view.onHover = onHover
        view.contextMenu = contextMenu
        if view.catHitRects != catHitRects {
            view.catHitRects = catHitRects
            view.window?.invalidateCursorRects(for: view)
        }
    }

    static func dismantleNSView(_ view: CatInteractionNSView, coordinator: ()) {
        view.finishPetting()
    }
}

final class CatInteractionNSView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    var catHitRects: [CGRect] = []
    var onPetStart: ((RoomPoint) -> Void)?
    var onPetMove: ((RoomPoint) -> Void)?
    var onPetEnd: (() -> Void)?
    var onHover: ((RoomPoint?) -> Void)?
    var contextMenu: ((RoomPoint) -> [RoomMenuItem])?

    private var hoverArea: NSTrackingArea?
    private var petting = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for rect in catHitRects {
            let visibleHit = rect.intersection(visibleRect)
            if !visibleHit.isEmpty { addCursorRect(visibleHit, cursor: .pointingHand) }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways,
                      .inVisibleRect, .enabledDuringMouseDrag],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { updatePointer(event) }
    override func mouseMoved(with event: NSEvent) { updatePointer(event) }
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        onHover?(nil)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control), popMenu(for: event) { return }
        let point = localPoint(event)
        petting = hitsCat(point)
        if petting { onPetStart?(point) }
    }

    /// A cat's menu, or, off the cats, whatever the notch offers on a right-click (its Settings menu).
    override func rightMouseDown(with event: NSEvent) {
        if !popMenu(for: event) { super.rightMouseDown(with: event) }
    }

    /// Shows the menu for the point; false when there is none to show.
    @discardableResult
    private func popMenu(for event: NSEvent) -> Bool {
        let items = contextMenu?(localPoint(event)) ?? []
        guard !items.isEmpty else { return false }
        let menu = NSMenu()
        for item in items {
            let target = MenuAction(item.action)
            let entry = NSMenuItem(title: item.title, action: #selector(MenuAction.fire), keyEquivalent: "")
            entry.target = target
            entry.representedObject = target   // keeps the target alive while the menu is up
            menu.addItem(entry)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        return true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = localPoint(event)
        updatePointer(event)
        if petting { onPetMove?(point) }
    }

    override func mouseUp(with event: NSEvent) { finishPetting() }

    func finishPetting() {
        guard petting else { return }
        petting = false
        onPetEnd?()
    }

    private func updatePointer(_ event: NSEvent) {
        let point = localPoint(event)
        onHover?(point)
        if hitsCat(point) {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func hitsCat(_ point: RoomPoint) -> Bool {
        catHitRects.contains { $0.contains(CGPoint(x: point.x, y: point.y)) }
    }

    private func localPoint(_ event: NSEvent) -> RoomPoint {
        let point = convert(event.locationInWindow, from: nil)
        return RoomPoint(x: point.x, y: point.y)
    }
}

/// An Objective-C target for one closure, so an `NSMenuItem` can call it.
private final class MenuAction: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func fire() { action() }
}
