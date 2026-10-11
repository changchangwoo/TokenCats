import Foundation
import Testing
@testable import TokenCatsCore

private func gregorian(_ zone: String, firstWeekday: Int = 1) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    calendar.firstWeekday = firstWeekday
    return calendar
}

private func at(_ calendar: Calendar, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private let thresholds = [3_000_000, 10_000_000]

struct ChuruCalendarTests {
    @Test func levelBandsAreFixed() {
        let levels = [0, 1, 2_999_999, 3_000_000, 9_999_999, 10_000_000, 40_000_000]
            .map { ChuruCalendar.level(for: $0, thresholds: thresholds) }
        #expect(levels == [0, 1, 1, 2, 2, 3, 3])
    }

    /// October 2026 starts on a Thursday; with Sunday-start weeks the grid opens on 27 September.
    @Test func sixWeekGridStartsOnTheWeekHoldingTheFirst() {
        let seoul = gregorian("Asia/Seoul", firstWeekday: 1)
        let month = ChuruCalendar.month(containing: at(seoul, 10, 10), installedAt: at(seoul, 1, 1),
                                        tokensByDay: [:], thresholds: thresholds, calendar: seoul)
        #expect(month.month == 10)
        #expect(month.days.count == 42)
        #expect(month.days[0] == CalendarDay(dayKey: "2026-09-27", state: .outsideMonth))
        #expect(month.days[4].dayKey == "2026-10-01")
        #expect(month.days[34].dayKey == "2026-10-31")
        #expect(month.days[35] == CalendarDay(dayKey: "2026-11-01", state: .outsideMonth))
        #expect(month.days.filter { $0.state == .outsideMonth }.count == 42 - 31)
    }

    @Test func todayIsMarkedAndLaterDaysThisMonthAreFuture() {
        let seoul = gregorian("Asia/Seoul", firstWeekday: 1)
        let month = ChuruCalendar.month(containing: at(seoul, 10, 10), installedAt: at(seoul, 1, 1),
                                        tokensByDay: [:], thresholds: thresholds, calendar: seoul)
        #expect(month.days[13] == CalendarDay(dayKey: "2026-10-10", state: .used(level: 0), isToday: true))
        #expect(month.days.filter(\.isToday).count == 1)
        #expect(month.days[14] == CalendarDay(dayKey: "2026-10-11", state: .future))
        #expect(month.days[34].state == .future)
    }

    @Test func mondayStartShiftsTheGrid() {
        let seoul = gregorian("Asia/Seoul", firstWeekday: 2)
        let month = ChuruCalendar.month(containing: at(seoul, 10, 10), installedAt: at(seoul, 1, 1),
                                        tokensByDay: [:], thresholds: thresholds, calendar: seoul)
        #expect(month.days[0].dayKey == "2026-09-28")
        #expect(month.days[3].dayKey == "2026-10-01")
        #expect(month.days[12].isToday)
    }

    @Test func installDayIsUsedAndEarlierDaysAreBeforeInstall() {
        let seoul = gregorian("Asia/Seoul")
        let month = ChuruCalendar.month(containing: at(seoul, 10, 10), installedAt: at(seoul, 10, 8, 15),
                                        tokensByDay: [:], thresholds: thresholds, calendar: seoul)
        let byKey = Dictionary(uniqueKeysWithValues: month.days.map { ($0.dayKey, $0.state) })
        #expect(byKey["2026-10-07"] == .beforeInstall)
        #expect(byKey["2026-10-08"] == .used(level: 0))
        #expect(byKey["2026-09-30"] == .outsideMonth)
    }

    @Test func recordedDaysUseTheirBandAndMissingDaysAreLevelZero() {
        let seoul = gregorian("Asia/Seoul")
        let month = ChuruCalendar.month(containing: at(seoul, 10, 10), installedAt: at(seoul, 10, 1),
                                        tokensByDay: ["2026-10-09": 4_000_000, "2026-10-10": 12_000_000],
                                        thresholds: thresholds, calendar: seoul)
        #expect(month.days[11].state == .used(level: 0))
        #expect(month.days[12].state == .used(level: 2))
        #expect(month.days[13].state == .used(level: 3))
    }

    /// Chile starts daylight saving at midnight on 2026-09-06, so that Sunday has no 00:00.
    /// Today must still be today, not the future, for the whole week.
    @Test func todayStaysTodayWhenDaylightSavingStartsAtMidnight() {
        let santiago = gregorian("America/Santiago")
        let month = ChuruCalendar.month(containing: at(santiago, 9, 8), installedAt: at(santiago, 1, 1),
                                        tokensByDay: [:], thresholds: thresholds, calendar: santiago)
        let today = month.days.first { $0.dayKey == "2026-09-08" }
        #expect(today == CalendarDay(dayKey: "2026-09-08", state: .used(level: 0), isToday: true))
        let keys = month.days.map(\.dayKey)
        #expect(Set(keys).count == 42)
        #expect(keys == keys.sorted())
    }

    /// US daylight saving ends on 2026-11-01; that day is 25 hours long.
    @Test func consecutiveAcrossDaylightSavingEnd() {
        let newYork = gregorian("America/New_York")
        let month = ChuruCalendar.month(containing: at(newYork, 11, 5), installedAt: at(newYork, 1, 1),
                                        tokensByDay: [:], thresholds: thresholds, calendar: newYork)
        let keys = month.days.map(\.dayKey)
        #expect(Set(keys).count == 42)
        #expect(keys == keys.sorted())
        #expect(month.days.first { $0.dayKey == "2026-11-05" }?.isToday == true)
    }

    @Test func wallCalendarIsGregorianWhateverTheMacsCalendar() {
        let seoul = gregorian("Asia/Seoul")
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = seoul.timeZone
        let now = at(seoul, 10, 10)
        let expected = ChuruCalendar.month(containing: now, installedAt: at(seoul, 9, 1), tokensByDay: [:],
                                           thresholds: [1, 2], calendar: seoul)
        #expect(ChuruCalendar.month(containing: now, installedAt: at(seoul, 9, 1), tokensByDay: [:],
                                    thresholds: [1, 2], calendar: hebrew) == expected)
    }

    /// Before the first churu count the wall still shows this month, every day blank, not a bare sheet.
    @Test func anEmptyMonthShowsTheMonthWithNoUse() {
        let seoul = gregorian("Asia/Seoul")
        let month = ChuruCalendar.empty(containing: at(seoul, 10, 10), calendar: seoul)
        #expect(month.month == 10)
        #expect(month.days.count == ChuruCalendar.rows * ChuruCalendar.daysPerWeek)
        #expect(!month.days.contains { if case let .used(level) = $0.state { return level > 0 } else { return false } })
    }
}
