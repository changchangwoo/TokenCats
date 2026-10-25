import CoreGraphics

/// Where the menu bar panel opens: centred under the icon, hanging from the menu bar, kept fully on screen.
/// AppKit coordinates (y grows upward); the result is the panel window's bottom-left corner.
enum MenuBarPanelPlacement {
    static func origin(iconMidX: CGFloat, visibleFrame: CGRect, panelSize: CGSize) -> CGPoint {
        let centred = iconMidX - panelSize.width / 2
        let x = min(max(centred, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
        return CGPoint(x: x, y: visibleFrame.maxY - panelSize.height)
    }
}
