import Foundation

/// Keeps the two petting poses visible during a click or a mouse drag over the cat.
struct CatPettingInteraction: Sendable {
    private var startedAt: Double?
    private var activeUntil: Double?
    private var pressing = false

    mutating func touch(at time: Double, point: RoomPoint, cat: CatRoomMotion, baseline: Double) -> Bool {
        guard time.isFinite, cat.isNear(point, baseline: baseline) else { return false }
        if frame(at: time) == nil { startedAt = time }
        pressing = true
        activeUntil = time + 0.7
        return true
    }

    mutating func end(at time: Double) {
        guard pressing, time.isFinite else { return }
        pressing = false
        activeUntil = max(activeUntil ?? time, time + 0.6)
    }

    func frame(at time: Double) -> Int? {
        guard let startedAt, time >= startedAt,
              pressing || time < (activeUntil ?? startedAt) else { return nil }
        return Int((time - startedAt) * 5) % 2
    }
}
