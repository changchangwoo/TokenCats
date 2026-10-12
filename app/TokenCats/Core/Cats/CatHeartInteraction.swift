import Foundation

enum CatHeartSide: Sendable { case left, right }

/// A visual response to clicking the resident cat; it never affects agent sessions or rewards.
struct CatHeartInteraction: Sendable {
    static let cooldown = 1.5
    static let duration = 0.9

    private var lastAcceptedAt: Double?
    private var startedAt: Double?
    private(set) var side: CatHeartSide = .left

    mutating func tap(at time: Double, point: RoomPoint, cat: CatRoomMotion, baseline: Double) -> Bool {
        guard time.isFinite, cat.isNear(point, baseline: baseline) else { return false }
        if let lastAcceptedAt, time - lastAcceptedAt < Self.cooldown { return false }
        lastAcceptedAt = time
        startedAt = time
        side = Bool.random() ? .left : .right
        return true
    }

    /// Starts a burst now whatever the cooldown; a treat is worth a heart even right after a pet.
    mutating func force(at time: Double) {
        guard time.isFinite else { return }
        lastAcceptedAt = time
        startedAt = time
        side = Bool.random() ? .left : .right
    }

    func progress(at time: Double) -> Double? {
        guard let startedAt else { return nil }
        let elapsed = time - startedAt
        guard elapsed >= 0, elapsed < Self.duration else { return nil }
        return elapsed / Self.duration
    }
}
