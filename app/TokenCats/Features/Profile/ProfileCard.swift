import Foundation

enum ProfileCardError: Error {
    /// The churu ledger has not finished its first count yet.
    case notReady
}

/// Builds the profile card SVG from the live data: this month, the year of day totals, and the cats.
/// Shared by "프로필 SVG 만들기" and the automatic GitHub sync.
@MainActor
enum ProfileCard {
    private static var history: JSONFile<DailyHistory> { DataFiles.live.dailyHistory }

    /// The first card scans every agent log once (about 30 seconds); later cards reuse the saved totals.
    static var needsFirstScan: Bool { history.load() == nil }


    /// `owner` is the connected GitHub login, shown in the card's footer.
    /// `theme` draws the card in another background (Debug previews); nil uses the applied one.
    static func render(owner: String? = nil, theme: RoomTheme? = nil) async throws -> String {
        let churu = ChuruModel.shared
        await churu.refresh()
        guard let snapshot = churu.snapshot else { throw ProfileCardError.notReady }
        let history = history
        let ledger = DataFiles.live.churu
        let todayTokens = snapshot.todayTokens
        // The first scan reads every log; keep it off the main thread.
        let daily = await Task.detached(priority: .utility) {
            ProfileHistory.dailyTokens(history: history, ledger: ledger, today: Date(), todayTokens: todayTokens,
                                       calendar: .current) { DailyTokenScan.scan() }
        }.value
        let options = AppSettings.profileCardOptions
        let year = ContributionYear.make(dailyTokens: daily, today: Date(),
                                         thresholds: ChuruRules.standard.calendarThresholds, calendar: .current)
        return try ProfileExport.svg(calendar: snapshot.calendar, year: options.showsYear ? year : nil,
                                     showsNumbers: options.showsNumbers, owner: owner, updated: Date(),
                                     theme: theme)
    }
}
