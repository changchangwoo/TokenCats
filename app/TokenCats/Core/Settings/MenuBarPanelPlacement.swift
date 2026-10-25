import CoreGraphics

/// Where the menu bar panel opens, the way system menu bar windows do: its leading edge lined up with the icon, a
/// small gap below the menu bar, kept a margin inside the screen. AppKit coordinates (y grows upward); the result is
/// the panel window's bottom-left corner.
enum MenuBarPanelPlacement {
    static let gap: CGFloat = 5
    static let margin: CGFloat = 8

    static func origin(icon: CGRect, visibleFrame: CGRect, panelSize: CGSize) -> CGPoint {
        let x = min(max(icon.minX, visibleFrame.minX + margin), visibleFrame.maxX - margin - panelSize.width)
        return CGPoint(x: x, y: visibleFrame.maxY - gap - panelSize.height)
    }
}
