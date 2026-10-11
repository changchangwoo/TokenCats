import Foundation

/// How tall the closed notch is when it follows the menu bar.
enum ClosedNotchHeight {
    /// Never thinner than this, so the cats and the hover area always have room.
    static let minimum = 24.0

    /// The menu bar's measured height (screen top minus the visible frame). An auto-hidden menu bar measures 0,
    /// which would make the notch vanish, so the system status bar's thickness stands in.
    static func menuBar(measured: Double, statusBarThickness: Double) -> Double {
        if measured > 0 { return measured }
        return statusBarThickness > 0 ? statusBarThickness : minimum
    }
}
