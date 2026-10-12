import Foundation

/// The three daily missions. Fixed in code: three missions do not need a catalog file.
enum MissionID: String, Codable, CaseIterable, Sendable {
    /// Always complete; claiming it is the check-in.
    case checkIn
    /// One petting gesture in the room today.
    case pet
    /// Today's processed tokens reach one million.
    case tokens1M
}

struct MissionRule: Codable, Equatable, Sendable {
    let id: MissionID
    let target: Int
    let baseReward: Int
}

enum MissionState: Equatable, Sendable {
    case inProgress
    case claimable
    /// Paid today; `reward` is what was paid, frozen.
    case claimed(reward: Int)
}

/// One mission as the Home shows it.
struct MissionStatus: Equatable, Sendable {
    let id: MissionID
    let progress: Int
    let target: Int
    /// What a claim pays now, or what it paid.
    let reward: Int
    let state: MissionState
}

/// Today's mission state. Replaced whole when the day key changes; unclaimed rewards go with it.
/// String keys (`MissionID.rawValue`) so the file holds a JSON object; an enum-keyed dictionary encodes as an array.
struct MissionDay: Codable, Equatable, Sendable {
    var day: String
    /// In-app actions so far today.
    var counts: [String: Int] = [:]
    /// Mission → churu paid, frozen at claim time.
    var claimed: [String: Int] = [:]

    var bonus: Int { claimed.values.reduce(0, +) }
}

/// Rewards and the streak multiplier. Pure; the ledger owns the state.
struct MissionRules: Codable, Equatable, Sendable {
    var missions: [MissionRule] = [
        MissionRule(id: .checkIn, target: 1, baseReward: 50_000),
        MissionRule(id: .pet, target: 1, baseReward: 50_000),
        MissionRule(id: .tokens1M, target: 1_000_000, baseReward: 150_000),
    ]
    /// Streak days that still raise the multiplier; 2.0× from here on.
    var maximumStreakForBonus = 10
    var bonusPerStreakDay = 0.1

    static let standard = MissionRules()

    func rule(_ id: MissionID) -> MissionRule? { missions.first { $0.id == id } }

    /// 1.0 with no streak, up by `bonusPerStreakDay` per day, capped at `maximumStreakForBonus` days.
    func multiplier(streak: Int) -> Double {
        1 + bonusPerStreakDay * Double(min(max(streak, 0), maximumStreakForBonus))
    }

    /// Whole churu; rounded, so 50_000 × 1.1 is 55_000 rather than a truncated 55_000.00000000001.
    func reward(for rule: MissionRule, streak: Int) -> Int {
        Int((Double(rule.baseReward) * multiplier(streak: streak)).rounded())
    }

    func statuses(day: MissionDay, todayTokens: Int, streak: Int) -> [MissionStatus] {
        missions.map { rule in
            let progress: Int
            switch rule.id {
            case .checkIn: progress = 1
            case .pet: progress = day.counts[rule.id.rawValue] ?? 0
            case .tokens1M: progress = todayTokens
            }
            if let paid = day.claimed[rule.id.rawValue] {
                return MissionStatus(id: rule.id, progress: max(progress, rule.target), target: rule.target,
                                     reward: paid, state: .claimed(reward: paid))
            }
            let reward = reward(for: rule, streak: streak)
            return MissionStatus(id: rule.id, progress: progress, target: rule.target, reward: reward,
                                 state: progress >= rule.target ? .claimable : .inProgress)
        }
    }
}
