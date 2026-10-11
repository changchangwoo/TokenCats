import Foundation

/// The room's cats beside the closed notch: the first half on the left wing, the rest on the right. Both wings are
/// as wide as the fuller one, so the black shape stays centred on the physical notch.
enum ClosedNotchCats {
    struct Wings<Cat: Equatable>: Equatable {
        let left: [Cat]
        let right: [Cat]
    }

    static func split<Cat: Equatable>(_ cats: [Cat]) -> Wings<Cat> {
        let half = cats.count / 2
        return Wings(left: Array(cats.prefix(half)), right: Array(cats.dropFirst(half)))
    }

    /// Points per size step. The cats use the store's 80-pixel portrait, so a notch of usual height shows them at
    /// 24pt, the size the store's adoption cards use.
    static let iconStep = 12.0
    /// Space kept above and below the icon inside the notch.
    static let iconMargin = 8.0

    /// The largest crisp icon size that fits the closed notch's height; 0 when none does.
    static func iconSize(notchHeight: Double) -> Double {
        (max(0, notchHeight - iconMargin) / iconStep).rounded(.down) * iconStep
    }

    /// Icon slots on each wing.
    static func wingSlots(count: Int) -> Int { (count + 1) / 2 }
}
