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

    /// Missions sit last: the balance and the agent limits are what a working day glances at.
    @Test func homeLedgerIsBalanceThenLimitsThenHistoryThenMissions() {
        #expect(HomeLayout.sections(for: .default) == [.balance, .limits, .history, .missions])
        var display = HomeDisplaySettings.default
        display.showAgentLimits = false
        #expect(HomeLayout.sections(for: display) == [.balance, .history, .missions])
        display.showMissions = false
        #expect(HomeLayout.sections(for: display) == [.balance, .history])
        display.showBalance = false
        display.showAdoptionProgress = false
        #expect(HomeLayout.sections(for: display) == [.history])
    }

    @Test func missionsSectionAddsItsHeightAndADivider() {
        typealias Layout = HomeLayout
        var display = HomeDisplaySettings.default
        let full = Layout.height(for: display)
        #expect(full == Layout.roomOnlyHeight + Layout.ledgerPadding + Layout.balanceHeight + Layout.missionsHeight
                + Layout.limitsHeight + Layout.historyHeight + Layout.dividerHeight * 3)
        #expect(Layout.maximumHeight == full)
        display.showMissions = false
        #expect(Layout.height(for: display) == full - Layout.missionsHeight - Layout.dividerHeight)
    }

    /// The user folds the missions section to one line with the chevron on its title row.
    @Test func missionsSectionFoldsToOneLine() {
        typealias Layout = HomeLayout
        let full = Layout.height(for: .default)
        #expect(Layout.height(for: .default, missionsExpanded: true) == full)
        #expect(Layout.height(for: .default, missionsExpanded: false)
                == full - Layout.missionsHeight + Layout.missionsFoldedHeight)
        #expect(Layout.height(of: .missions, expanded: false) == Layout.missionsFoldedHeight)
        var hidden = HomeDisplaySettings.default
        hidden.showMissions = false
        #expect(Layout.height(for: hidden, missionsExpanded: false) == Layout.height(for: hidden))
    }

    @Test func detailedChartsDoNotEnlargeHome() {
        typealias Layout = HomeLayout
        var display = HomeDisplaySettings.default
        let full = Layout.height(for: display)
        #expect(full == Layout.roomOnlyHeight + Layout.ledgerPadding + Layout.balanceHeight + Layout.missionsHeight
                + Layout.limitsHeight + Layout.historyHeight + Layout.dividerHeight * 3)
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
        display.showMissions = false
        #expect(Layout.height(for: display) == Layout.roomOnlyHeight + Layout.ledgerPadding + Layout.balanceHeight)
        display.showBalance = false
        display.showAdoptionProgress = false
        #expect(Layout.height(for: display) == Layout.roomOnlyHeight)
    }
}
