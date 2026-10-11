import Foundation

/// How one day on the wall calendar is drawn.
enum CalendarDayState: Equatable, Sendable {
    /// A day of the previous or next month that fills the grid; no square is drawn.
    case outsideMonth
    /// This month, but before the app was installed; drawn as an empty square.
    case beforeInstall
    /// Later this month; drawn as an empty square.
    case future
    /// Level 0...3 from that day's processed tokens.
    case used(level: Int)
}

struct CalendarDay: Equatable, Sendable {
    let dayKey: String
    let state: CalendarDayState
    var isToday = false
}

/// The month shown on the wall calendar: six weeks starting with the week that holds the 1st.
struct ChuruMonthCalendar: Equatable, Sendable {
    /// 1...12.
    let month: Int
    /// 42 cells, row by row, oldest first.
    let days: [CalendarDay]
}

/// This month's churu, one square per day, for the calendar on the cat room wall.
/// Only the month and levels leave this type; token counts and day numbers are never drawn.
enum ChuruCalendar {
    static let rows = 6
    static let daysPerWeek = 7

    /// Fixed bands: no tokens → 0, below the first threshold → 1, below the second → 2, the rest → 3.
    /// Fixed so a past square never changes colour after a big day.
    static func level(for tokens: Int, thresholds: [Int]) -> Int {
        tokens <= 0 ? 0 : 1 + thresholds.filter { tokens >= $0 }.count
    }

    /// This month with no record yet, for the wall before the first churu count finishes.
    static func empty(containing now: Date, calendar: Calendar) -> ChuruMonthCalendar {
        month(containing: now, installedAt: now, tokensByDay: [:], thresholds: ChuruRules.standard.calendarThresholds,
              calendar: calendar)
    }

    /// Always six rows so the calendar keeps its size; weeks start on `calendar.firstWeekday`.
    /// Days are compared by their `yyyy-MM-dd` keys, not instants: where daylight saving starts at
    /// midnight a day begins at 01:00, and instant comparisons would push today into the future.
    static func month(containing now: Date, installedAt: Date, tokensByDay: [String: Int],
                      thresholds: [Int], calendar: Calendar) -> ChuruMonthCalendar {
        let calendar = calendar.gregorian
        let month = calendar.component(.month, from: now)
        let todayKey = ChuruLedger.dayKey(now, calendar)
        let installKey = ChuruLedger.dayKey(installedAt, calendar)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        let days = (0..<(rows * daysPerWeek)).compactMap { offset -> CalendarDay? in
            // Noon keeps every step inside its day whatever the daylight-saving shifts.
            guard let date = calendar.date(byAdding: .day, value: offset,
                                           to: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: gridStart)
                                               ?? gridStart)
            else { return nil }
            let key = ChuruLedger.dayKey(date, calendar)
            let state: CalendarDayState
            if calendar.component(.month, from: date) != month {
                state = .outsideMonth
            } else if key < installKey {
                state = .beforeInstall
            } else if key > todayKey {
                state = .future
            } else {
                state = .used(level: level(for: tokensByDay[key] ?? 0, thresholds: thresholds))
            }
            return CalendarDay(dayKey: key, state: state, isToday: key == todayKey)
        }
        return ChuruMonthCalendar(month: month, days: days)
    }
}
