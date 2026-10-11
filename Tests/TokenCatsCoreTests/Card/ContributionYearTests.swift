import Foundation
import Testing
@testable import TokenCatsCore

private func gregorian(firstWeekday: Int = 1) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    calendar.firstWeekday = firstWeekday
    return calendar
}
private let seoul = gregorian()
private let today = seoul.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 12))!
private let thresholds = [3_000_000, 10_000_000]

private func days(_ keys: [String], _ tokens: Int = 1_000_000) -> [String: Int] {
    Dictionary(uniqueKeysWithValues: keys.map { ($0, tokens) })
}
private func range(_ month: Int, _ from: Int, _ to: Int) -> [String] {
    (from...to).map { String(format: "2026-%02d-%02d", month, $0) }
}

struct ContributionYearTests {
    @Test func fiftyThreeWeeksEndingWithThisWeek() {
        let year = ContributionYear.make(dailyTokens: [:], today: today, thresholds: thresholds, calendar: seoul)
        #expect(year.columns.count == 53)
        #expect(year.columns.allSatisfy { $0.count == 7 })
        #expect(year.columns[0][0].dayKey == "2025-10-05")
        #expect(year.columns[52][6] == ContributionCell(dayKey: "2026-10-10", level: 0))
    }

    @Test func daysAfterTodayHaveNoSquare() {
        let year = ContributionYear.make(dailyTokens: [:], today: today, thresholds: thresholds, calendar: gregorian(firstWeekday: 2))
        #expect(year.columns[52][6] == ContributionCell(dayKey: "2026-10-11", level: nil))
    }

    @Test func levelsUseTheChuruBands() {
        let year = ContributionYear.make(dailyTokens: ["2026-10-09": 4_000_000, "2026-10-10": 12_000_000],
                                         today: today, thresholds: thresholds, calendar: seoul)
        #expect(year.columns[52][5].level == 2)
        #expect(year.columns[52][6].level == 3)
    }

    @Test func monthNamesSitOverTheirFirstWeekWithoutCrowding() {
        let year = ContributionYear.make(dailyTokens: [:], today: today, thresholds: thresholds, calendar: seoul)
        #expect(year.monthLabels.first == MonthLabel(column: 0, name: "Oct"))
        #expect(year.monthLabels.contains(MonthLabel(column: 4, name: "Nov")))
        #expect(year.monthLabels.suffix(2) == [MonthLabel(column: 48, name: "Sep"), MonthLabel(column: 52, name: "Oct")])
        let columns = year.monthLabels.map(\.column)
        #expect(zip(columns, columns.dropFirst()).allSatisfy { $1 - $0 >= 3 })
    }

    @Test func statsAndStreaks() {
        let daily = days(range(9, 1, 6) + range(10, 1, 4) + range(10, 7, 10))
        let year = ContributionYear.make(dailyTokens: daily, today: today, thresholds: thresholds, calendar: seoul)
        #expect(year.total == 14_000_000)
        #expect(year.averagePerActiveDay == 1_000_000)
        #expect(year.currentStreak == 4)
        #expect(year.longestStreak == 6)
        #expect(year.headline(showsNumbers: true) == "14.0M tokens in the last year · 1.0M/day avg · 4-day streak (best 6)")
    }

    @Test func currentStreakCountsFromYesterdayWhenTodayIsEmpty() {
        let year = ContributionYear.make(dailyTokens: days(range(10, 7, 9)), today: today,
                                         thresholds: thresholds, calendar: seoul)
        #expect(year.currentStreak == 3)
    }

    @Test func statsCoverOnlyTheLastYear() {
        let year = ContributionYear.make(dailyTokens: ["2025-10-01": 50_000_000, "2026-10-10": 2_000_000],
                                         today: today, thresholds: thresholds, calendar: seoul)
        #expect(year.total == 2_000_000)
        #expect(year.longestStreak == 1)
    }

    @Test func statsAreThreeTiles() {
        let daily = days(range(9, 1, 6) + range(10, 1, 4) + range(10, 7, 10))
        let year = ContributionYear.make(dailyTokens: daily, today: today, thresholds: thresholds, calendar: seoul)
        #expect(year.stats(showsNumbers: true) == [
            YearStat(title: "TOTAL TOKENS", value: "14.0M", unit: nil, caption: "Last 365 days"),
            YearStat(title: "DAILY AVERAGE", value: "1.0M", unit: nil, caption: "Tokens / active day"),
            YearStat(title: "CURRENT STREAK", value: "4", unit: "days", caption: "Personal best · 6 days"),
        ])
        let one = ContributionYear.make(dailyTokens: days(["2026-10-10"]), today: today, thresholds: thresholds, calendar: seoul)
        #expect(one.stats(showsNumbers: true).last == YearStat(title: "CURRENT STREAK", value: "1", unit: "day",
                                                               caption: "Personal best · 1 day"))
        #expect(year.stats(showsNumbers: false).isEmpty)
    }

    @Test func headlines() {
        let empty = ContributionYear.make(dailyTokens: [:], today: today, thresholds: thresholds, calendar: seoul)
        #expect(empty.headline(showsNumbers: true) == "No agent activity yet")
        #expect(empty.headline(showsNumbers: false) == "Coding agent activity in the last year")
        let broken = ContributionYear.make(dailyTokens: days(range(9, 1, 3)), today: today,
                                           thresholds: thresholds, calendar: seoul)
        #expect(broken.headline(showsNumbers: true) == "3.0M tokens in the last year · 1.0M/day avg · best 3-day streak")
    }

    private func seoulCalendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    /// A Hebrew year has a 13th month; the grid still labels Gregorian months and never runs past the names.
    @Test func aHebrewCalendarStillLabelsGregorianMonths() {
        let today = Date(timeIntervalSince1970: 1_791_590_400)
        let gregorian = ContributionYear.make(dailyTokens: [:], today: today, thresholds: [1, 2], calendar: seoulCalendar(.gregorian))
        let hebrew = ContributionYear.make(dailyTokens: [:], today: today, thresholds: [1, 2], calendar: seoulCalendar(.hebrew))
        #expect(hebrew.monthLabels.map(\.name) == gregorian.monthLabels.map(\.name))
    }
}
