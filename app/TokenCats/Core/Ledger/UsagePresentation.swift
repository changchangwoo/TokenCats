import Foundation

/// A provider adapter supplies what it actually knows; the Home view does not assume 5-hour or weekly limits.
struct UsageSource: Sendable {
    enum State: Equatable, Sendable { case ready, waiting, needsConnection }

    let id: String
    let name: String
    let state: State
    let metrics: [UsageMetric]
    var observedAt: Date? = nil
}

struct UsageMetric: Sendable {
    let kind: LimitWindowKind
    let value: String
    /// Nil when a provider reports a count or a status without a usable percentage.
    let fraction: Double?
    let resetsAt: Date?
}

/// What a provider's card says when its details are folded away: its state, or its fullest window.
enum UsageSummary: Equatable, Sendable {
    case needsConnection, waiting, noLimits, reset
    /// `value` is nil while values are hidden.
    case metric(LimitWindowKind, value: String?)
}

/// What a detail row says after its figure.
enum UsageNote: Equatable, Sendable {
    case reset
    case resetsIn(ResetCountdown)
    /// The reading is older than `UsageDashboard.staleAfter`.
    case stale(minutes: Int)
}

struct UsageCard: Identifiable, Sendable {
    let id: String
    let name: String
    let summary: UsageSummary
    let state: UsageSource.State
    let details: [UsageDetail]
}

struct UsageDetail: Sendable {
    let kind: LimitWindowKind
    /// The emphasised figure ("7%"), nil when values are hidden or the window has reset.
    let value: String?
    let notes: [UsageNote]
    let fraction: Double?
    let tier: LimitTier
}

enum UsagePresentation {
    static func cards(sources: [UsageSource], settings: HomeDisplaySettings, now: Date) -> [UsageCard] {
        sources.enumerated()
            .filter { !settings.hiddenProviderIDs.contains($0.element.id) }
            .sorted { lhs, rhs in
                let left = settings.providerOrder.firstIndex(of: lhs.element.id) ?? Int.max
                let right = settings.providerOrder.firstIndex(of: rhs.element.id) ?? Int.max
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map { _, source in card(source, settings: settings, now: now) }
    }

    private static func card(_ source: UsageSource, settings: HomeDisplaySettings, now: Date) -> UsageCard {
        let summary: UsageSummary
        switch source.state {
        case .needsConnection: summary = .needsConnection
        case .waiting: summary = .waiting
        case .ready:
            let active = source.metrics.filter { $0.resetsAt.map { $0 > now } ?? true }
            if let metric = active.max(by: { ($0.fraction ?? -1) < ($1.fraction ?? -1) }) {
                summary = .metric(metric.kind, value: settings.showUsageValues ? metric.value : nil)
            } else {
                summary = source.metrics.isEmpty ? .noLimits : .reset
            }
        }
        let details = source.metrics.map { metric in
            let expired = metric.resetsAt.map { $0 <= now } ?? false
            let fraction: Double? = expired ? 0 : metric.fraction.map { min(max($0, 0), 1) }
            var notes: [UsageNote] = []
            if expired {
                notes.append(.reset)
            } else if settings.showResetTime, let reset = metric.resetsAt {
                notes.append(.resetsIn(UsageDashboard.countdown(until: reset, now: now)))
            }
            if let observed = source.observedAt, now.timeIntervalSince(observed) > UsageDashboard.staleAfter {
                notes.append(.stale(minutes: Int(now.timeIntervalSince(observed) / 60)))
            }
            return UsageDetail(kind: metric.kind, value: !expired && settings.showUsageValues ? metric.value : nil,
                               notes: notes, fraction: settings.showUsageBars ? fraction : nil,
                               tier: UsageDashboard.tier((fraction ?? 0) * 100))
        }
        return UsageCard(id: source.id, name: source.name, summary: summary, state: source.state,
                         details: details)
    }
}
