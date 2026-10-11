import AppKit
import SwiftUI

/// Native hit regions, one per cat, so macOS owns the pointing-hand cursor and mouse dragging.
struct CatInteractionSurface: NSViewRepresentable {
    let catHitRects: [CGRect]
    let onPetStart: (RoomPoint) -> Void
    let onPetMove: (RoomPoint) -> Void
    let onPetEnd: () -> Void

    func makeNSView(context: Context) -> CatInteractionNSView { CatInteractionNSView() }

    func updateNSView(_ view: CatInteractionNSView, context: Context) {
        view.onPetStart = onPetStart
        view.onPetMove = onPetMove
        view.onPetEnd = onPetEnd
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
    }

    override func mouseDown(with event: NSEvent) {
        let point = localPoint(event)
        petting = hitsCat(point)
        if petting { onPetStart?(point) }
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
