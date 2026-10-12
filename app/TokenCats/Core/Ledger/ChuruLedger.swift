import Foundation

/// Churu is processed tokens, one for one, with no daily cap, plus the daily mission bonuses.
/// Prices live in the store catalog.
struct ChuruRules: Codable, Equatable, Sendable {
    /// Wall calendar bands in processed tokens per day: level 1 below the first, 2 below the second, 3 above.
    /// Set from 2026-10 measurements (2.8M–17M on working days).
    var calendarThresholds: [Int] = [3_000_000, 10_000_000]
    var missions: MissionRules = .standard

    static let standard = ChuruRules()
}

struct ChuruDay: Codable, Equatable, Sendable {
    var tokens: Int
    /// Mission rewards claimed that day, frozen when the day rolled over. Absent in files from before missions.
    var bonus: Int = 0

    init(tokens: Int, bonus: Int = 0) {
        self.tokens = tokens
        self.bonus = bonus
    }

    private enum CodingKeys: String, CodingKey { case tokens, bonus }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try values.decode(Int.self, forKey: .tokens)
        bonus = try values.decodeIfPresent(Int.self, forKey: .bonus) ?? 0
    }
}

/// What the Home footer and the profile info line show.
struct ChuruSnapshot: Equatable, Sendable {
    let day: String
    let todayTokensByProvider: [TokenProvider: Int]
    /// Churu on hand: tokens since install plus mission bonuses, minus what was spent.
    let balance: Int
    /// Processed tokens since install; bonuses are not tokens.
    let lifetimeTokens: Int
    let streakDays: Int
    let refreshedAt: Date
    /// This month for the wall calendar; month and levels only.
    let calendar: ChuruMonthCalendar
    /// Today's three missions in display order.
    let missions: [MissionStatus]
    /// Mission churu claimed today.
    let todayBonus: Int
    /// What the streak multiplies today's rewards by.
    let missionMultiplier: Double

    var todayTokens: Int { todayTokensByProvider.values.reduce(0, +) }
    /// How far the balance is toward `price`, 0...1.
    func progress(toward price: Int) -> Double {
        price > 0 ? min(1, Double(max(0, balance)) / Double(price)) : 0
    }

    /// The same snapshot after `amount` was spent, so the UI need not rescan logs after a purchase.
    func spending(_ amount: Int) -> ChuruSnapshot {
        ChuruSnapshot(day: day, todayTokensByProvider: todayTokensByProvider, balance: balance - amount,
                      lifetimeTokens: lifetimeTokens, streakDays: streakDays, refreshedAt: refreshedAt,
                      calendar: calendar, missions: missions, todayBonus: todayBonus,
                      missionMultiplier: missionMultiplier)
    }
}

/// Churu earned from token usage since install.
///
/// Today is recomputed from the logs on every refresh, so reading the same log twice never credits twice.
/// Once a day is over its total is frozen, so later refreshes only scan logs from the open day onward;
/// days the app was not running are still credited on the next refresh.
struct ChuruLedger: Codable, Equatable {
    let installedAt: Date
    /// Start of the earliest day not yet frozen; logs modified since then are scanned.
    private(set) var openFrom: Date
    private(set) var frozenDays: [String: ChuruDay] = [:]
    private(set) var spent = 0
    /// Today's missions; nil until the first `apply`. Optional in the file: absent before missions existed.
    private(set) var missionDay: MissionDay?

    init(installedAt: Date) {
        self.installedAt = installedAt
        openFrom = installedAt
    }

    mutating func apply(_ entries: [TokenEntry], now: Date, rules: ChuruRules = .standard,
                        calendar: Calendar = .current) -> ChuruSnapshot {
        let today = Self.dayKey(now, calendar)
        // A clock that ran ahead and was set back would leave today before the open day forever.
        if now < openFrom { openFrom = max(installedAt, calendar.startOfDay(for: now)) }
        var byDay: [String: [TokenProvider: Int]] = [:]
        // Usage before install is never counted.
        for entry in entries where entry.timestamp >= installedAt && entry.timestamp >= openFrom {
            byDay[Self.dayKey(entry.timestamp, calendar), default: [:]][entry.provider, default: 0] += entry.processed
        }
        for (day, providers) in byDay where day < today {
            // A bonus rolled into this day earlier stays; only the tokens are (re)counted.
            frozenDays[day] = ChuruDay(tokens: providers.values.reduce(0, +), bonus: frozenDays[day]?.bonus ?? 0)
        }
        openFrom = max(openFrom, calendar.startOfDay(for: now))
        rollMissionDay(to: today)
        return snapshot(todayTokensByProvider: byDay[today] ?? [:], now: now, rules: rules, calendar: calendar)
    }

    /// Midnight for missions: claimed rewards become the old day's frozen bonus, unclaimed ones are dropped.
    /// A mission day in the future (clock set back) is discarded without freezing anything.
    private mutating func rollMissionDay(to today: String) {
        if let current = missionDay, current.day != today {
            if current.day < today, current.bonus > 0 {
                frozenDays[current.day, default: ChuruDay(tokens: 0)].bonus += current.bonus
            }
            missionDay = nil
        }
        if missionDay == nil { missionDay = MissionDay(day: today) }
    }

    /// The snapshot for today's tokens as last read from the logs. `apply` ends here; `record` and `claim`
    /// callers use it to publish a new balance without rescanning.
    func snapshot(todayTokensByProvider: [TokenProvider: Int], now: Date, rules: ChuruRules = .standard,
                  calendar: Calendar = .current) -> ChuruSnapshot {
        let today = Self.dayKey(now, calendar)
        let day = missionDay.flatMap { $0.day == today ? $0 : nil } ?? MissionDay(day: today)
        let todayTokens = todayTokensByProvider.values.reduce(0, +)
        let lifetime = frozenDays.values.reduce(0) { $0 + $1.tokens } + todayTokens
        let bonuses = frozenDays.values.reduce(0) { $0 + $1.bonus } + day.bonus
        var tokensByDay = frozenDays.mapValues(\.tokens)
        tokensByDay[today] = todayTokens
        let streak = streak(today: today, todayTokens: todayTokens, now: now, calendar: calendar)
        return ChuruSnapshot(
            day: today,
            todayTokensByProvider: todayTokensByProvider,
            balance: lifetime + bonuses - spent,
            lifetimeTokens: lifetime,
            streakDays: streak,
            refreshedAt: now,
            calendar: ChuruCalendar.month(containing: now, installedAt: installedAt, tokensByDay: tokensByDay,
                                          thresholds: rules.calendarThresholds, calendar: calendar),
            missions: rules.missions.statuses(day: day, todayTokens: todayTokens, streak: streak),
            todayBonus: day.bonus,
            missionMultiplier: rules.missions.multiplier(streak: streak))
    }

    /// Counts an in-app action toward today's mission. False (nothing to save) once the target is met,
    /// when no mission day exists yet, or when the mission day is not `today` (the next `apply` rolls it).
    mutating func record(_ id: MissionID, today: String, rules: MissionRules) -> Bool {
        guard var day = missionDay, day.day == today, let rule = rules.rule(id) else { return false }
        let count = day.counts[id.rawValue] ?? 0
        guard count < rule.target else { return false }
        day.counts[id.rawValue] = count + 1
        missionDay = day
        return true
    }

    /// Pays a claimable mission once. `snapshot` must come from this ledger on the same day; the reward it
    /// shows is what gets paid, frozen. nil when the mission is not claimable or was already claimed.
    mutating func claim(_ id: MissionID, snapshot: ChuruSnapshot) -> Int? {
        guard var day = missionDay, day.day == snapshot.day, day.claimed[id.rawValue] == nil,
              let status = snapshot.missions.first(where: { $0.id == id }), status.state == .claimable
        else { return nil }
        day.claimed[id.rawValue] = status.reward
        missionDay = day
        return status.reward
    }

    /// Spends churu if the balance covers it.
    mutating func spend(_ amount: Int, balance: Int) -> Bool {
        guard amount > 0, amount <= balance else { return false }
        spent += amount
        return true
    }

    /// Consecutive days with usage, ending today (or yesterday while today has none yet).
    private func streak(today: String, todayTokens: Int, now: Date, calendar: Calendar) -> Int {
        var count = todayTokens > 0 ? 1 : 0
        var date = now
        while let previous = calendar.date(byAdding: .day, value: -1, to: date),
              let day = frozenDays[Self.dayKey(previous, calendar)], day.tokens > 0 {
            count += 1
            date = previous
        }
        return count
    }

    static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Reads the logs, updates the ledger, and saves it. Not thread-safe: callers confine it to one serial queue.
final class ChuruTracker: @unchecked Sendable {
    private let reader: TokenUsageReader
    private let file: JSONFile<ChuruLedger>
    let rules: ChuruRules
    let calendar: Calendar
    private(set) var ledger: ChuruLedger?
    /// Today's tokens as of the last refresh, so a mission tap can publish a balance without rescanning.
    private var lastTodayTokensByProvider: [TokenProvider: Int] = [:]

    init(reader: TokenUsageReader, file: JSONFile<ChuruLedger>, rules: ChuruRules = .standard,
         calendar: Calendar = .current) {
        self.reader = reader
        self.file = file
        self.rules = rules
        self.calendar = calendar
    }

    static var live: ChuruTracker {
        ChuruTracker(reader: TokenUsageReader(),
                     file: DataFiles.live.churu)
    }

    func refresh(now: Date = Date()) -> ChuruSnapshot {
        // The first refresh after install sets the baseline; earlier usage is not counted.
        var current = ledger ?? file.load() ?? ChuruLedger(installedAt: now)
        let snapshot = current.apply(reader.entries(modifiedSince: current.openFrom), now: now,
                                     rules: rules, calendar: calendar)
        if current != ledger { file.save(current) }
        ledger = current
        lastTodayTokensByProvider = snapshot.todayTokensByProvider
        return snapshot
    }

    /// Spends against `balance`, which the caller must have just computed with `refresh` on this same queue.
    /// Nothing changes unless the ledger is saved.
    @discardableResult
    func spend(_ amount: Int, balance: Int) -> Bool {
        guard var current = ledger, current.spend(amount, balance: balance), file.save(current) else { return false }
        ledger = current
        return true
    }

    /// Counts an in-app action (a pet) without reading the logs. nil before the first refresh; otherwise the
    /// snapshot with the count, written only when it changed, so a petting spree is one write a day.
    func record(_ id: MissionID, now: Date = Date()) -> ChuruSnapshot? {
        let today = ChuruLedger.dayKey(now, calendar)
        // Past midnight the cached tokens are yesterday's: let the next refresh roll the day instead of
        // publishing a balance built from stale numbers.
        guard var current = ledger, current.missionDay?.day == today else { return nil }
        if current.record(id, today: today, rules: rules.missions), file.save(current) {
            ledger = current
        }
        return (ledger ?? current).snapshot(todayTokensByProvider: lastTodayTokensByProvider, now: now,
                                           rules: rules, calendar: calendar)
    }

    /// Re-reads the logs, then pays the mission if it is claimable. The refreshed snapshot comes back unchanged
    /// when the claim is refused or the ledger could not be saved.
    func claim(_ id: MissionID, now: Date = Date()) -> ChuruSnapshot {
        let snapshot = refresh(now: now)
        guard var current = ledger, current.claim(id, snapshot: snapshot) != nil, file.save(current) else {
            return snapshot
        }
        ledger = current
        return current.snapshot(todayTokensByProvider: snapshot.todayTokensByProvider, now: now,
                                rules: rules, calendar: calendar)
    }
}
