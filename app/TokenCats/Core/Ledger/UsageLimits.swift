import Foundation

enum LimitProvider: String, Sendable {
    case claude, codex

    var displayName: String { self == .claude ? "Claude" : "Codex" }
}

/// What a usage window measures. Providers report these; the screens name them.
enum LimitWindowKind: Equatable, Sendable {
    case fiveHour, daily, weekly, requests
    /// Any other rolling window, in whole hours.
    case hours(Int)
}

/// One usage window as the provider reported it.
struct LimitWindow: Equatable, Sendable {
    let kind: LimitWindowKind
    let usedPercent: Double
    let resetsAt: Date
}

/// The windows one provider reported, and when.
struct LimitReading: Equatable, Sendable {
    let provider: LimitProvider
    let windows: [LimitWindow]
    let observedAt: Date
}

enum LimitTier: Equatable, Sendable {
    case normal, warning, critical
}

/// Time left until a window resets, in the units worth saying: minutes under an hour, hours and minutes under
/// a day, days and hours from then on (`minutes` is 0 there).
struct ResetCountdown: Equatable, Sendable {
    let days: Int
    let hours: Int
    let minutes: Int
}

/// Shared rules for whatever limit windows a provider actually reports.
enum UsageDashboard {
    static let staleAfter: TimeInterval = 600

    /// Below 70% normal, from 70% warning, from 90% critical (ccseva's alert thresholds).
    static func tier(_ percent: Double) -> LimitTier {
        percent >= 90 ? .critical : percent >= 70 ? .warning : .normal
    }

    /// Rounded up to the minute so "0 minutes" never shows.
    static func countdown(until resetsAt: Date, now: Date) -> ResetCountdown {
        let minutes = max(1, Int((resetsAt.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return ResetCountdown(days: 0, hours: 0, minutes: minutes) }
        if minutes < 1_440 { return ResetCountdown(days: 0, hours: minutes / 60, minutes: minutes % 60) }
        return ResetCountdown(days: minutes / 1_440, hours: minutes % 1_440 / 60, minutes: 0)
    }
}
