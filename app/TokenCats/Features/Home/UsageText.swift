import SwiftUI

/// The words for the usage dashboard's values. Core says what a window is and what is left; this says it.
extension LimitWindowKind {
    var title: LocalizedStringResource {
        switch self {
        case .fiveHour: return "5-hour"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .fableWeekly: return "Weekly · Fable"
        case .requests: return "Requests"
        case .hours(let hours): return "\(hours)-hour"
        }
    }
}

extension ResetCountdown {
    /// Short units ("2d 3h") so the row fits the notch in any language.
    var text: LocalizedStringResource {
        if days > 0 { return hours == 0 ? "Resets in \(days)d" : "Resets in \(days)d \(hours)h" }
        if hours > 0 { return minutes == 0 ? "Resets in \(hours)h" : "Resets in \(hours)h \(minutes)m" }
        return "Resets in \(minutes)m"
    }
}

extension UsageNote {
    var text: LocalizedStringResource {
        switch self {
        case .reset: return "Reset"
        case .resetsIn(let countdown): return countdown.text
        case .stale(let minutes):
            return minutes < 60 ? "\(minutes) minutes old" : "\(minutes / 60) hours old"
        }
    }
}

extension UsageSummary {
    var text: LocalizedStringResource {
        switch self {
        case .needsConnection: return "Needs connection"
        case .waiting: return "Waiting for a response"
        case .noLimits: return "No limit information"
        case .reset: return "Reset"
        case .metric(let kind, let value):
            return value.map { "\(kind.title) \($0)" } ?? kind.title
        }
    }
}

extension UsageDetail {
    /// The notes after the figure, " · " apart; nil without notes.
    var noteText: Text? {
        notes.map { Text($0.text) }.reduce(nil) { joined, note in
            joined.map { $0 + Text(verbatim: " · ") + note } ?? note
        }
    }
}

extension CostEstimate {
    static var explanation: LocalizedStringKey { """
    An estimate at public API prices. It can differ from what a subscription bills, and usage of models without \
    a known price is left out of the amount.
    """ }
}
