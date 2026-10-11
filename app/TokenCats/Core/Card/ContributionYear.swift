import Foundation

struct ContributionCell: Equatable, Sendable {
    let dayKey: String
    /// nil for days after today: no square.
    let level: Int?
}

/// The same pixel stamp is used in the profile SVG and the notch grass.
/// The paw that marks TokenCats: on the card's tile titles and next to the name in the app, 16 × 16 pixels.
enum BrandPaw {
    static let rows = ["................", "....oo....oo....", "...oooo..oooo...", "...oooo..oooo...",
                       "....oo....oo....", ".oo..........oo.", "oooo........oooo", "oooo..oooo..oooo",
                       ".oo..oooooo..oo.", "....oooooooo....", "...oooooooooo...", "...oooooooooo...",
                       "...oooooooooo...", "....oooooooo....", ".....oo..oo.....", "................"]
}

enum ContributionPaw {
    static let rows = ["............", "............",
                       "...XX..XX...", "...XX..XX...", ".XX......XX.", ".XX..XX..XX.",
                       "....XXXX....", "...XXXXXX...", "...XXXXXX...", "....XXXX...."]
}

/// One line of the numbers list over the graph: a bold value and its label. An empty value is a title line.
/// One tile over the graph: a small title, a big value with an optional unit, and a caption.
struct YearStat: Equatable, Sendable {
    let title: String
    let value: String
    let unit: String?
    let caption: String
}

struct MonthLabel: Equatable, Sendable {
    let column: Int
    let name: String
}

/// The last year of agent tokens as a GitHub-style graph: 53 weeks of 7 days, month names over the weeks,
/// and the year's numbers. Only the profile SVG draws it.
struct ContributionYear: Equatable, Sendable {
    static let weeks = 53
    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    let columns: [[ContributionCell]]
    let monthLabels: [MonthLabel]
    let total: Int
    let averagePerActiveDay: Int
    let currentStreak: Int
    let longestStreak: Int

    /// The last column is the week holding `today`, starting on `calendar.firstWeekday`. Numbers cover the
    /// 365 days ending today. Days are stepped from noon and compared by key, so daylight saving cannot shift them.
    static func make(dailyTokens: [String: Int], today: Date, thresholds: [Int], calendar: Calendar) -> ContributionYear {
        let calendar = calendar.gregorian
        let noon = { (date: Date) in calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date }
        let todayKey = ChuruLedger.dayKey(today, calendar)
        let weekStart = noon(calendar.dateInterval(of: .weekOfYear, for: calendar.startOfDay(for: today))?.start ?? today)
        let first = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: weekStart) ?? weekStart

        var columns: [[ContributionCell]] = []
        var labels: [MonthLabel] = []
        var previousMonth: Int?
        for week in 0..<weeks {
            var column: [ContributionCell] = []
            for day in 0..<7 {
                let date = calendar.date(byAdding: .day, value: week * 7 + day, to: first) ?? first
                let key = ChuruLedger.dayKey(date, calendar)
                column.append(ContributionCell(
                    dayKey: key,
                    level: key > todayKey ? nil : ChuruCalendar.level(for: dailyTokens[key] ?? 0, thresholds: thresholds)))
                if day == 0 {
                    let month = calendar.component(.month, from: date)
                    if month != previousMonth, labels.last.map({ week - $0.column >= 3 }) ?? true {
                        labels.append(MonthLabel(column: week, name: monthNames[month - 1]))
                    }
                    previousMonth = month
                }
            }
            columns.append(column)
        }

        let todayNoon = noon(today)
        let window = (0..<365).reversed().map { offset in
            dailyTokens[ChuruLedger.dayKey(calendar.date(byAdding: .day, value: -offset, to: todayNoon) ?? todayNoon,
                                           calendar)] ?? 0
        }
        let total = window.reduce(0, +)
        let active = window.filter { $0 > 0 }.count
        var longest = 0, run = 0
        for tokens in window {
            run = tokens > 0 ? run + 1 : 0
            longest = max(longest, run)
        }
        var current = 0
        for tokens in window.dropLast(window.last == 0 ? 1 : 0).reversed() {
            guard tokens > 0 else { break }
            current += 1
        }
        return ContributionYear(columns: columns, monthLabels: labels, total: total,
                                averagePerActiveDay: active > 0 ? total / active : 0,
                                currentStreak: current, longestStreak: longest)
    }

    /// The numbers over the graph as a list. Without numbers it only says what the graph is.
    /// The three tiles; empty when numbers are off or there is nothing yet (the card shows `headline` instead).
    func stats(showsNumbers: Bool) -> [YearStat] {
        guard showsNumbers, total > 0 else { return [] }
        let days = { (count: Int) in count == 1 ? "day" : "days" }
        return [
            YearStat(title: "TOTAL TOKENS", value: TokenCount.compact(total), unit: nil, caption: "Last 365 days"),
            YearStat(title: "DAILY AVERAGE", value: TokenCount.compact(averagePerActiveDay), unit: nil,
                     caption: "Tokens / active day"),
            YearStat(title: "CURRENT STREAK", value: "\(currentStreak)", unit: days(currentStreak),
                     caption: "Personal best · \(longestStreak) \(days(longestStreak))"),
        ]
    }

    /// The line over the graph. Without numbers it only says what the graph is.
    func headline(showsNumbers: Bool) -> String {
        guard showsNumbers else { return "Coding agent activity in the last year" }
        guard total > 0 else { return "No agent activity yet" }
        let streak = currentStreak > 0 ? "\(currentStreak)-day streak (best \(longestStreak))"
                                       : "best \(longestStreak)-day streak"
        return ["\(TokenCount.compact(total)) tokens in the last year",
                "\(TokenCount.compact(averagePerActiveDay))/day avg", streak].joined(separator: " · ")
    }
}
