import Foundation

struct WeekUsageDay: Equatable, Sendable {
    let dayKey: String
    let weekday: Int
    let tokens: Int
}

/// A rolling seven-day window ending today, in the user's local calendar.
struct WeekUsage: Equatable, Sendable {
    let days: [WeekUsageDay]
    var total: Int { days.reduce(0) { $0 + $1.tokens } }
    var peak: Int { days.map(\.tokens).max() ?? 0 }

    static func make(dailyTokens: [String: Int], today: Date, calendar: Calendar) -> WeekUsage {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        let days = (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: noon) ?? noon
            let key = ChuruLedger.dayKey(date, calendar)
            return WeekUsageDay(dayKey: key, weekday: calendar.component(.weekday, from: date),
                                tokens: dailyTokens[key] ?? 0)
        }
        return WeekUsage(days: days)
    }
}

/// Home remains a glanceable size; charts and grass live in Statistics.
/// The ledger under Home's room: churu on hand, the agents' limits, then the usage record, divided by thin lines.
enum HomeSection: Equatable, Sendable {
    case balance, limits, history, missions
}

/// Home's open height follows the sections the user keeps on; detailed charts live in Statistics and never add height.
enum HomeLayout {
    /// The header and the 190pt room with no ledger under it.
    static let roomOnlyHeight = 230.0
    /// The ledger's top and bottom padding.
    static let ledgerPadding = 24.0
    static let balanceHeight = 44.0
    /// A title row (about 15pt), three 20pt mission rows and 4pt gaps.
    static let missionsHeight = 88.0
    /// The missions section folded to its title line by the user (the chevron on its title row).
    static let missionsFoldedHeight = 20.0
    /// Two usage windows and a provider status line. A third window adds one row.
    static let limitsHeight = 116.0
    static let limitRowHeight = 27.0
    static let historyHeight = 66.0
    /// A divider line with the space above and below it.
    static let dividerHeight = 17.0
    static let maximumHeight = height(for: .default, limitRows: 3)

    static func sections(for display: HomeDisplaySettings) -> [HomeSection] {
        var sections: [HomeSection] = []
        if display.showBalance || display.showAdoptionProgress { sections.append(.balance) }
        if display.showAgentLimits { sections.append(.limits) }
        if display.showWeeklyTokens || display.showTodayTokens || display.showEstimatedCost || display.showStreak {
            sections.append(.history)
        }
        // Last: a working day glances at the balance and the limits; missions are the once-a-day visit.
        if display.showMissions { sections.append(.missions) }
        return sections
    }

    static func height(of section: HomeSection, expanded: Bool = true, limitRows: Int = 2) -> Double {
        switch section {
        case .balance: return balanceHeight
        case .missions: return expanded ? missionsHeight : missionsFoldedHeight
        case .limits: return limitsHeight + Double(min(max(limitRows, 1), 3) - 2) * limitRowHeight
        case .history: return historyHeight
        }
    }

    static func height(for display: HomeDisplaySettings, missionsExpanded: Bool = true,
                       limitRows: Int = 2) -> Double {
        let sections = sections(for: display)
        guard !sections.isEmpty else { return roomOnlyHeight }
        return roomOnlyHeight + ledgerPadding + sections.map { height(of: $0, expanded: missionsExpanded,
                                                                      limitRows: limitRows) }.reduce(0, +)
            + dividerHeight * Double(sections.count - 1)
    }
}
