import SwiftUI

/// Shares the profile card's day totals. The first full scan runs off the main thread and is saved on disk.
@MainActor
final class HomeUsageHistoryModel: ObservableObject {
    static let shared = HomeUsageHistoryModel()

    @Published private(set) var week: WeekUsage?
    @Published private(set) var year: ContributionYear?
    private var lastDay: String?
    private var lastTodayTokens: Int?
    private var loading = false

    func refresh(day: String, todayTokens: Int) {
        guard !loading, lastDay != day || lastTodayTokens != todayTokens else { return }
        loading = true
        lastDay = day
        lastTodayTokens = todayTokens
        let today = Date()
        Task.detached(priority: .utility) { [weak self] in
            let files = DataFiles.live
            let days = ProfileHistory.dailyTokens(
                history: files.dailyHistory,
                ledger: files.churu,
                today: today, todayTokens: todayTokens, calendar: .current) { DailyTokenScan.scan() }
            let week = WeekUsage.make(dailyTokens: days, today: today, calendar: .current)
            let year = ContributionYear.make(dailyTokens: days, today: today,
                                             thresholds: ChuruRules.standard.calendarThresholds, calendar: .current)
            await MainActor.run {
                guard let self else { return }
                self.week = week
                self.year = year
                self.loading = false
                if let latest = ChuruModel.shared.snapshot,
                   self.lastDay != latest.day || self.lastTodayTokens != latest.todayTokens {
                    self.refresh(day: latest.day, todayTokens: latest.todayTokens)
                }
            }
        }
    }
}
