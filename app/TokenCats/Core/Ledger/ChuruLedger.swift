import Foundation

/// Churu is processed tokens, one for one, with no daily cap. Prices live in the store catalog.
struct ChuruRules: Codable, Equatable, Sendable {
    /// Wall calendar bands in processed tokens per day: level 1 below the first, 2 below the second, 3 above.
    /// Set from 2026-10 measurements (2.8M–17M on working days).
    var calendarThresholds: [Int] = [3_000_000, 10_000_000]

    static let standard = ChuruRules()
}

struct ChuruDay: Codable, Equatable, Sendable {
    var tokens: Int
}

/// What the Home footer and the profile info line show.
struct ChuruSnapshot: Equatable, Sendable {
    let day: String
    let todayTokensByProvider: [TokenProvider: Int]
    /// Churu on hand: tokens since install minus what was spent.
    let balance: Int
    let lifetimeTokens: Int
    let streakDays: Int
    let refreshedAt: Date
    /// This month for the wall calendar; month and levels only.
    let calendar: ChuruMonthCalendar

    var todayTokens: Int { todayTokensByProvider.values.reduce(0, +) }
    /// How far the balance is toward `price`, 0...1.
    func progress(toward price: Int) -> Double {
        price > 0 ? min(1, Double(max(0, balance)) / Double(price)) : 0
    }

    /// The same snapshot after `amount` was spent, so the UI need not rescan logs after a purchase.
    func spending(_ amount: Int) -> ChuruSnapshot {
        ChuruSnapshot(day: day, todayTokensByProvider: todayTokensByProvider, balance: balance - amount,
                      lifetimeTokens: lifetimeTokens, streakDays: streakDays, refreshedAt: refreshedAt,
                      calendar: calendar)
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
            frozenDays[day] = ChuruDay(tokens: providers.values.reduce(0, +))
        }
        openFrom = max(openFrom, calendar.startOfDay(for: now))

        let todayByProvider = byDay[today] ?? [:]
        let todayTokens = todayByProvider.values.reduce(0, +)
        let lifetime = frozenDays.values.reduce(0) { $0 + $1.tokens } + todayTokens
        var tokensByDay = frozenDays.mapValues(\.tokens)
        tokensByDay[today] = todayTokens
        return ChuruSnapshot(
            day: today,
            todayTokensByProvider: todayByProvider,
            balance: lifetime - spent,
            lifetimeTokens: lifetime,
            streakDays: streak(today: today, todayTokens: todayTokens, now: now, calendar: calendar),
            refreshedAt: now,
            calendar: ChuruCalendar.month(containing: now, installedAt: installedAt, tokensByDay: tokensByDay,
                                          thresholds: rules.calendarThresholds, calendar: calendar))
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
}
