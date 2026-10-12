import Foundation

/// How a cat's bond grows. Every level costs the same, so the bar fills at one speed from Lv.1 to Lv.99 and the
/// whole pace is one constant, `levelCost`. Points are the only stored progress; level and bar are derived.
enum CatBondRules {
    static let maxLevel = 99
    static let levelCost = 300
    /// One full day of presence; the unit the other rewards are expressed in.
    static let dayPoints = 1_000
    static let presenceDailyCap = 1_000
    /// Four points a minute: 250 minutes of running fill a day, one level every 75 minutes.
    static let presencePointsPerMinute = 4
    /// Elapsed time beyond this is dropped, so sleep and pauses never credit in a lump.
    static let presenceMaxGapMinutes = 5.0
    /// Per accepted heart; the heart cooldown (`CatHeartInteraction.cooldown`) paces it.
    static let petPoints = 10
    static let treatPoints = 1_000
    /// Points at Lv.99. Nothing accrues past it.
    static let maxPoints = (maxLevel - 1) * levelCost

    static func level(points: Int) -> Int { min(maxLevel, 1 + max(0, points) / levelCost) }

    /// How far into the current level, 0...1. Full at the last level.
    static func progress(points: Int) -> Double {
        guard level(points: points) < maxLevel else { return 1 }
        return Double(max(0, points) % levelCost) / Double(levelCost)
    }
}

/// One cat's bond. `day` and `presenceToday` hold today's presence credit; `lastPresenceAt` is the clock the next
/// presence tick measures from.
struct CatBondRecord: Codable, Equatable, Sendable {
    var points = 0
    var day = ""
    var presenceToday = 0
    var lastPresenceAt: Date?

    var level: Int { CatBondRules.level(points: points) }
    var progress: Double { CatBondRules.progress(points: points) }
}

/// Every cat's bond, by cat id. Unknown ids read as a fresh Lv.1 and are created on their first change, so cats
/// adopted before bonds existed need no migration.
struct CatBondBook: Codable, Equatable, Sendable {
    private(set) var bonds: [String: CatBondRecord] = [:]

    init() {}

    func record(of id: String) -> CatBondRecord { bonds[id] ?? CatBondRecord() }
    func level(of id: String) -> Int { record(of: id).level }
    func progress(of id: String) -> Double { record(of: id).progress }

    /// One accepted heart.
    mutating func pet(_ id: String) { add(CatBondRules.petPoints, to: id) }

    /// One churu treat.
    mutating func treat(_ id: String) { add(CatBondRules.treatPoints, to: id) }

    /// A released cat.
    mutating func forget(_ id: String) { bonds[id] = nil }

    /// Credits the time since each cat's last tick, at most `presenceMaxGapMinutes`, within today's cap. The first
    /// tick only starts the clock. Cats not listed keep their clock, so a cat moved back into the room gets at most
    /// one capped gap, never the time it was stored. When nothing is credited (cap reached, Lv.99, under a minute)
    /// the clock stays where it was, so the book is unchanged and nothing needs writing.
    mutating func accruePresence(for ids: [String], now: Date, calendar: Calendar = .current) {
        let today = ChuruLedger.dayKey(now, calendar)
        for id in ids {
            var record = record(of: id)
            if record.day != today {
                record.day = today
                record.presenceToday = 0
            }
            guard let last = record.lastPresenceAt else {
                record.lastPresenceAt = now
                bonds[id] = record
                continue
            }
            let elapsed = now.timeIntervalSince(last) / 60
            if elapsed < 0 {
                // The clock went backwards; measure from here on.
                record.lastPresenceAt = now
                bonds[id] = record
                continue
            }
            let minutes = Int(min(CatBondRules.presenceMaxGapMinutes, elapsed))
            let credit = min(minutes * CatBondRules.presencePointsPerMinute,
                             CatBondRules.presenceDailyCap - record.presenceToday,
                             CatBondRules.maxPoints - record.points)
            if credit > 0 {
                record.points += credit
                record.presenceToday += credit
                record.lastPresenceAt = now
            }
            bonds[id] = record
        }
    }

    private mutating func add(_ points: Int, to id: String) {
        var record = record(of: id)
        record.points = min(CatBondRules.maxPoints, record.points + points)
        bonds[id] = record
    }
}
