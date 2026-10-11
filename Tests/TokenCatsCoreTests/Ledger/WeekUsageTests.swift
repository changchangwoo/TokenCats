import Foundation
import Testing
@testable import TokenCatsCore

struct WeekUsageTests {
    @Test func lastSevenDaysIncludesTodayAndUsesLocalCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 20))!
        let week = WeekUsage.make(dailyTokens: ["2026-10-04": 100, "2026-10-09": 200, "2026-10-10": 300],
                                  today: today, calendar: calendar)
        #expect(week.days.count == 7)
        #expect(week.days.first?.dayKey == "2026-10-04")
        #expect(week.days.last?.dayKey == "2026-10-10")
        #expect(week.days.map(\.tokens) == [100, 0, 0, 0, 0, 200, 300])
        #expect(week.total == 600)
    }

    @Test func homeLedgerIsBalanceThenLimitsThenHistory() {
        #expect(HomeLayout.sections(for: .default) == [.balance, .limits, .history])
        var display = HomeDisplaySettings.default
        display.showAgentLimits = false
        #expect(HomeLayout.sections(for: display) == [.balance, .history])
        display.showBalance = false
        display.showAdoptionProgress = false
        #expect(HomeLayout.sections(for: display) == [.history])
    }

    @Test func detailedChartsDoNotEnlargeHome() {
        typealias Layout = HomeLayout
        var display = HomeDisplaySettings.default
        let full = Layout.height(for: display)
        #expect(full == Layout.roomOnlyHeight + Layout.ledgerPadding + Layout.balanceHeight + Layout.limitsHeight
                + Layout.historyHeight + Layout.dividerHeight * 2)
        #expect(Layout.maximumHeight == full)
        display.showContributionGraph = false
        display.showWeeklyChart = false
        #expect(Layout.height(for: display) == full)
        display.showAgentLimits = false
        #expect(Layout.height(for: display) == full - Layout.limitsHeight - Layout.dividerHeight)
        display.showWeeklyTokens = false
        display.showTodayTokens = false
        display.showEstimatedCost = false
        display.showStreak = false
        #expect(Layout.height(for: display) == Layout.roomOnlyHeight + Layout.ledgerPadding + Layout.balanceHeight)
        display.showBalance = false
        display.showAdoptionProgress = false
        #expect(Layout.height(for: display) == Layout.roomOnlyHeight)
    }
}
