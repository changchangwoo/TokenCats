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

    /// Points per icon step: a 24-pixel icon on a 2x screen lands on whole device pixels at multiples of 12pt.
    static let iconStep = 12.0
    /// Space kept above and below the icon inside the notch.
    static let iconMargin = 8.0

    /// The largest crisp icon size that fits the closed notch's height; 0 when none does.
    static func iconSize(notchHeight: Double) -> Double {
        (max(0, notchHeight - iconMargin) / iconStep).rounded(.down) * iconStep
    }

    /// Waiting sessions shown as dots on the room's cats: one session per cat in order; the rest are counted.
    struct Alerts: Equatable {
        let byCat: [String: NotchSlot]
        let overflow: Int
    }

    static func alerts(sessions: [AgentSession], cats: [String]) -> Alerts {
        let layout = NotchSlots.layout(for: sessions, limit: cats.count)
        guard !sessions.isEmpty else { return Alerts(byCat: [:], overflow: 0) }
        return Alerts(byCat: Dictionary(uniqueKeysWithValues: zip(cats, layout.slots)), overflow: layout.overflow)
    }

    /// Icon slots on each wing.
    static func wingSlots(count: Int) -> Int { (count + 1) / 2 }
}
