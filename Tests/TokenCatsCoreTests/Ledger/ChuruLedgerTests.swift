import Foundation
import Testing
@testable import TokenCatsCore

private let seoul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}()

/// Local Seoul time.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
    seoul.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

private func usage(_ provider: TokenProvider, _ date: Date, _ tokens: Int) -> TokenEntry {
    TokenEntry(provider: provider, key: UUID().uuidString, timestamp: date, processed: tokens, cacheRead: 0)
}

private func usage(_ date: Date, _ tokens: Int) -> TokenEntry { usage(.claude, date, tokens) }

private let rules = ChuruRules()

struct ChuruLedgerTests {
    /// A clock set ahead and then corrected must not leave today's usage behind the ledger's open day.
    @Test func aClockSetAheadThenCorrectedStillCountsToday() {
        var ledger = ChuruLedger(installedAt: at(10, 12))
        _ = ledger.apply([], now: at(20, 9), rules: rules, calendar: seoul)
        let snapshot = ledger.apply([usage(at(11, 13), 120_000)], now: at(11, 14), rules: rules, calendar: seoul)
        #expect(snapshot.todayTokens == 120_000)
        #expect(snapshot.balance == 120_000)
    }

    @Test func countsOnlyUsageAfterInstall() {
        var ledger = ChuruLedger(installedAt: at(10, 12))
        let snapshot = ledger.apply([usage(at(10, 9), 900_000), usage(at(10, 13), 120_000)],
                                    now: at(10, 14), rules: rules, calendar: seoul)
        #expect(snapshot.todayTokens == 120_000)
        #expect(snapshot.balance == 120_000)
    }

    @Test func churuIsTokensOneForOneWithNoDailyCap() {
        var ledger = ChuruLedger(installedAt: at(10, 0))
        let snapshot = ledger.apply([usage(at(10, 10), 10_000_000)], now: at(10, 11), rules: rules, calendar: seoul)
        #expect(snapshot.balance == 10_000_000)
        #expect(snapshot.lifetimeTokens == 10_000_000)
    }

    @Test func gaugeFillsTowardAPrice() {
        var ledger = ChuruLedger(installedAt: at(10, 0))
        let quarter = ledger.apply([usage(at(10, 10), 250_000)], now: at(10, 11), rules: rules, calendar: seoul)
        #expect(quarter.progress(toward: 1_000_000) == 0.25)
        #expect(quarter.progress(toward: 100_000) == 1)
        #expect(quarter.progress(toward: 0) == 0)
        #expect(quarter.spending(50_000).balance == 200_000)
        #expect(quarter.spending(50_000).todayTokens == quarter.todayTokens)
    }

    @Test func applyingTheSameLogsTwiceNeverCreditsTwice() {
        var ledger = ChuruLedger(installedAt: at(10, 0))
        let entries = [usage(at(10, 10), 300_000), usage(.codex, at(10, 11), 100_000)]
        let first = ledger.apply(entries, now: at(10, 12), rules: rules, calendar: seoul)
        let second = ledger.apply(entries, now: at(10, 12), rules: rules, calendar: seoul)
        #expect(first == second)
        #expect(second.balance == 400_000)
        #expect(second.todayTokensByProvider == [.claude: 300_000, .codex: 100_000])
    }

    @Test func freezesPastDaysIncludingDaysTheAppWasOff() {
        var ledger = ChuruLedger(installedAt: at(10, 0))
        _ = ledger.apply([usage(at(10, 10), 200_000)], now: at(10, 12), rules: rules, calendar: seoul)
        // App off on the 11th; next refresh on the 12th sees both days in the logs.
        let entries = [usage(at(10, 10), 200_000), usage(at(11, 15), 5_000_000), usage(at(12, 9), 100_000)]
        let snapshot = ledger.apply(entries, now: at(12, 10), rules: rules, calendar: seoul)
        #expect(ledger.frozenDays["2026-10-10"] == ChuruDay(tokens: 200_000))
        #expect(ledger.frozenDays["2026-10-11"] == ChuruDay(tokens: 5_000_000))
        #expect(snapshot.todayTokens == 100_000)
        #expect(snapshot.balance == 5_300_000)
        #expect(snapshot.lifetimeTokens == 5_300_000)
        #expect(ledger.openFrom == at(12, 0))
    }

    @Test func splitsUsageAtLocalMidnight() {
        var ledger = ChuruLedger(installedAt: at(9, 0))
        let snapshot = ledger.apply([usage(at(9, 23, 59), 100_000), usage(at(10, 0, 1), 50_000)],
                                    now: at(10, 1), rules: rules, calendar: seoul)
        #expect(ledger.frozenDays["2026-10-09"]?.tokens == 100_000)
        #expect(snapshot.day == "2026-10-10")
        #expect(snapshot.todayTokens == 50_000)
    }

    @Test func countsConsecutiveDaysWithUsage() {
        var ledger = ChuruLedger(installedAt: at(6, 0))
        let entries = [usage(at(6, 10), 1), usage(at(8, 10), 1), usage(at(9, 10), 1)]
        let morning = ledger.apply(entries, now: at(10, 8), rules: rules, calendar: seoul)
        #expect(morning.streakDays == 2)  // today has no usage yet; the 8th and 9th count
        let later = ledger.apply([usage(at(10, 9), 1)], now: at(10, 10), rules: rules, calendar: seoul)
        #expect(later.streakDays == 3)
    }

    @Test func spendsOnlyWhatTheBalanceCovers() {
        var ledger = ChuruLedger(installedAt: at(10, 0))
        let snapshot = ledger.apply([usage(at(10, 10), 500_000)], now: at(10, 11), rules: rules, calendar: seoul)
        let tooMuch = ledger.spend(500_001, balance: snapshot.balance)
        let enough = ledger.spend(500_000, balance: snapshot.balance)
        let after = ledger.apply([usage(at(10, 10), 500_000)], now: at(10, 11), rules: rules, calendar: seoul)
        #expect(!tooMuch)
        #expect(enough)
        #expect(after.balance == 0)
    }

    @Test func trackerSetsTheBaselineOnFirstRunAndPersists() throws {
        let dir = try makeTempDirectory()
        let logs = dir.appendingPathComponent("claude/p")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let line = """
        {"type":"assistant","requestId":"r","timestamp":"2026-10-10T01:00:00.000Z","message":{"id":"m","usage":{"input_tokens":100000,"output_tokens":0}}}

        """
        try line.write(to: logs.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)
        let file = JSONFile<ChuruLedger>(url: dir.appendingPathComponent("churu.json"))
        func tracker() -> ChuruTracker {
            ChuruTracker(reader: TokenUsageReader(roots: .init(claude: [dir.appendingPathComponent("claude")], codex: [])),
                         file: file, rules: rules, calendar: seoul)
        }

        // Installed at 11:00 Seoul (02:00Z): the 10:00 Seoul line predates install.
        let first = tracker().refresh(now: at(10, 11))
        #expect(first.todayTokens == 0)
        #expect(file.load()?.installedAt == at(10, 11))

        // A new process loads the same baseline instead of installing again.
        try (line.replacingOccurrences(of: "01:00:00", with: "03:00:00").replacingOccurrences(of: "\"m\"", with: "\"m2\""))
            .write(to: logs.appendingPathComponent("s2.jsonl"), atomically: true, encoding: .utf8)
        // Scanning filters by modification time, which must fall inside the test's fixed clock.
        try FileManager.default.setAttributes([.modificationDate: at(10, 12)], ofItemAtPath: logs.appendingPathComponent("s2.jsonl").path)
        let second = tracker().refresh(now: at(10, 13))
        #expect(second.todayTokens == 100_000)
        #expect(second.balance == 100_000)
    }

    /// October 2026 opens on a Thursday and `seoul` starts weeks on Sunday, so 10 October is cell 13.
    /// The reader rescans from the earliest open day, so yesterday's entry arrives with today's.
    @Test func snapshotCarriesTheMonthCalendar() {
        var ledger = ChuruLedger(installedAt: at(9, 0))
        let snapshot = ledger.apply([usage(at(9, 10), 4_000_000), usage(at(10, 10), 12_000_000)],
                                    now: at(10, 14), rules: rules, calendar: seoul)
        #expect(snapshot.calendar.month == 10)
        #expect(snapshot.calendar.days.count == 42)
        #expect(snapshot.calendar.days[13] == CalendarDay(dayKey: "2026-10-10", state: .used(level: 3), isToday: true))
        #expect(snapshot.calendar.days[12] == CalendarDay(dayKey: "2026-10-09", state: .used(level: 2)))
        #expect(snapshot.calendar.days[11] == CalendarDay(dayKey: "2026-10-08", state: .beforeInstall))
    }

    private func seoulCalendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    /// Day keys stay Gregorian whatever calendar the Mac uses: Hebrew has 13 months, Japanese counts years by era.
    @Test func dayKeysAreGregorianWhateverTheMacsCalendar() {
        let day = Date(timeIntervalSince1970: 1_791_590_400)
        for identifier in [Calendar.Identifier.gregorian, .hebrew, .japanese, .buddhist, .persian] {
            #expect(ChuruLedger.dayKey(day, seoulCalendar(identifier)) == "2026-10-10", "\(identifier)")
        }
    }

    // MARK: Missions

    @Test func aFreshDayStartsWithCheckInClaimableAndNoBonus() {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        let snapshot = ledger.apply([usage(at(12, 9), 10_000)], now: at(12, 10), rules: rules, calendar: seoul)
        #expect(ledger.missionDay == MissionDay(day: "2026-10-12"))
        #expect(snapshot.missions.map(\.state) == [.claimable, .inProgress, .inProgress])
        #expect(snapshot.todayBonus == 0)
        #expect(snapshot.missionMultiplier == 1.1)  // today has usage: streak 1
        #expect(snapshot.balance == 10_000)
    }

    @Test func claimingAddsTheRewardToTheBalanceAndFreezesIt() {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        let before = ledger.apply([usage(at(12, 9), 10_000)], now: at(12, 10), rules: rules, calendar: seoul)
        let paid = ledger.claim(.checkIn, snapshot: before)
        #expect(paid == 55_000)
        let after = ledger.snapshot(todayTokensByProvider: before.todayTokensByProvider, now: at(12, 10),
                                    rules: rules, calendar: seoul)
        #expect(after.balance == 65_000)
        #expect(after.todayBonus == 55_000)
        #expect(after.missions[0].state == .claimed(reward: 55_000))
        #expect(after.lifetimeTokens == 10_000)  // tokens only
        #expect(ledger.missionDay?.claimed == ["checkIn": 55_000])
    }

    @Test func claimingTwiceOnTheSameDayPaysOnce() {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        let first = ledger.apply([], now: at(12, 10), rules: rules, calendar: seoul)
        let result1 = ledger.claim(.checkIn, snapshot: first)
        #expect(result1 == 50_000)
        // A second tap that still holds the old snapshot, and one with a fresh snapshot: both refused.
        let result2 = ledger.claim(.checkIn, snapshot: first)
        #expect(result2 == nil)
        let fresh = ledger.snapshot(todayTokensByProvider: [:], now: at(12, 10), rules: rules, calendar: seoul)
        let result3 = ledger.claim(.checkIn, snapshot: fresh)
        #expect(result3 == nil)
        #expect(fresh.balance == 50_000)
    }

    @Test func claimingAnUnfinishedMissionIsRefused() {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        let snapshot = ledger.apply([usage(at(12, 9), 999_999)], now: at(12, 10), rules: rules, calendar: seoul)
        let result4 = ledger.claim(.pet, snapshot: snapshot)
        #expect(result4 == nil)
        let result5 = ledger.claim(.tokens1M, snapshot: snapshot)
        #expect(result5 == nil)
        #expect(ledger.missionDay?.claimed.isEmpty == true)
    }

    @Test func aSnapshotFromAnotherDayCannotClaim() {
        var ledger = ChuruLedger(installedAt: at(11, 0))
        let yesterday = ledger.apply([], now: at(11, 10), rules: rules, calendar: seoul)
        _ = ledger.apply([], now: at(12, 10), rules: rules, calendar: seoul)
        let result6 = ledger.claim(.checkIn, snapshot: yesterday)
        #expect(result6 == nil)
    }

    @Test func recordingAPetCountsOnceUpToTheTarget() {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        _ = ledger.apply([], now: at(12, 10), rules: rules, calendar: seoul)
        let result7 = ledger.record(.pet, today: "2026-10-12", rules: rules.missions)
        #expect(result7)
        let result21 = ledger.record(.pet, today: "2026-10-12", rules: rules.missions)
        #expect(!result21)  // target met: nothing to save
        #expect(ledger.missionDay?.counts == ["pet": 1])
        let snapshot = ledger.snapshot(todayTokensByProvider: [:], now: at(12, 10), rules: rules, calendar: seoul)
        #expect(snapshot.missions[1].state == .claimable)
    }

    @Test func recordingOnAStaleOrMissingDayIsIgnored() {
        var ledger = ChuruLedger(installedAt: at(11, 0))
        let result22 = ledger.record(.pet, today: "2026-10-11", rules: rules.missions)
        #expect(!result22)  // no day yet
        _ = ledger.apply([], now: at(11, 10), rules: rules, calendar: seoul)
        let result23 = ledger.record(.pet, today: "2026-10-12", rules: rules.missions)
        #expect(!result23)  // day rolled, not yet applied
        #expect(ledger.missionDay?.counts.isEmpty == true)
    }

    /// Midnight: claimed rewards move into the day's frozen bonus; unclaimed ones are gone.
    @Test func dayChangeFreezesClaimedBonusesAndDropsUnclaimed() {
        var ledger = ChuruLedger(installedAt: at(11, 0))
        let day1 = ledger.apply([usage(at(11, 9), 2_000_000)], now: at(11, 10), rules: rules, calendar: seoul)
        let result8 = ledger.claim(.checkIn, snapshot: day1)
        #expect(result8 == 55_000)
        // tokens1M was claimable but never claimed.
        let day2 = ledger.apply([usage(at(11, 9), 2_000_000), usage(at(12, 9), 1)], now: at(12, 10),
                                rules: rules, calendar: seoul)
        #expect(ledger.frozenDays["2026-10-11"] == ChuruDay(tokens: 2_000_000, bonus: 55_000))
        #expect(ledger.missionDay == MissionDay(day: "2026-10-12"))
        #expect(day2.todayBonus == 0)
        #expect(day2.missions.map(\.state) == [.claimable, .inProgress, .inProgress])
        #expect(day2.balance == 2_000_001 + 55_000)
    }

    /// The app was off on the 11th: the 12th's refresh freezes the 11th's tokens and rolls its bonus in one go.
    @Test func tokensAndBonusOfThePreviousDayFreezeTogether() {
        var ledger = ChuruLedger(installedAt: at(11, 0))
        let day1 = ledger.apply([], now: at(11, 8), rules: rules, calendar: seoul)
        let result9 = ledger.claim(.checkIn, snapshot: day1)
        #expect(result9 == 50_000)
        let day2 = ledger.apply([usage(at(11, 15), 300_000)], now: at(12, 10), rules: rules, calendar: seoul)
        #expect(ledger.frozenDays["2026-10-11"] == ChuruDay(tokens: 300_000, bonus: 50_000))
        #expect(day2.balance == 350_000)
    }

    @Test func aFrozenBonusIgnoresLaterRuleChanges() {
        var ledger = ChuruLedger(installedAt: at(11, 0))
        let day1 = ledger.apply([], now: at(11, 8), rules: rules, calendar: seoul)
        let result10 = ledger.claim(.checkIn, snapshot: day1)
        #expect(result10 == 50_000)
        var generous = ChuruRules()
        generous.missions.missions = [MissionRule(id: .checkIn, target: 1, baseReward: 5_000_000)]
        let day2 = ledger.apply([], now: at(12, 10), rules: generous, calendar: seoul)
        #expect(day2.balance == 50_000)
        #expect(day2.missions[0].reward == 5_000_000)
    }

    @Test func spendSucceedsAgainstBonusOnlyBalance() {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        let before = ledger.apply([], now: at(12, 10), rules: rules, calendar: seoul)
        let result11 = ledger.claim(.checkIn, snapshot: before)
        #expect(result11 == 50_000)
        let funded = ledger.snapshot(todayTokensByProvider: [:], now: at(12, 10), rules: rules, calendar: seoul)
        let result12 = ledger.spend(50_000, balance: funded.balance)
        #expect(result12)
        let after = ledger.snapshot(todayTokensByProvider: [:], now: at(12, 10), rules: rules, calendar: seoul)
        #expect(after.balance == 0)
    }

    @Test func clockSetBackPastTheMissionDayStartsOver() {
        var ledger = ChuruLedger(installedAt: at(10, 0))
        let ahead = ledger.apply([], now: at(14, 10), rules: rules, calendar: seoul)
        let result13 = ledger.claim(.checkIn, snapshot: ahead)
        #expect(result13 == 50_000)
        let corrected = ledger.apply([], now: at(12, 10), rules: rules, calendar: seoul)
        #expect(ledger.missionDay == MissionDay(day: "2026-10-12"))
        #expect(ledger.frozenDays["2026-10-14"] == nil)  // a future day's claim is not kept
        #expect(corrected.balance == 0)
    }

    @Test func decodesALedgerWrittenBeforeMissions() throws {
        let json = """
        {"installedAt":781000000,"openFrom":781000000,"spent":1000,
         "frozenDays":{"2026-10-10":{"tokens":200000}}}
        """
        let ledger = try JSONDecoder().decode(ChuruLedger.self, from: Data(json.utf8))
        #expect(ledger.frozenDays["2026-10-10"] == ChuruDay(tokens: 200_000, bonus: 0))
        #expect(ledger.missionDay == nil)
        #expect(ledger.spent == 1000)
    }

    @Test func missionDayRoundTripsThroughJSON() throws {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        let snapshot = ledger.apply([], now: at(12, 10), rules: rules, calendar: seoul)
        _ = ledger.claim(.checkIn, snapshot: snapshot)
        _ = ledger.record(.pet, today: "2026-10-12", rules: rules.missions)
        let data = try JSONEncoder().encode(ledger)
        #expect(try JSONDecoder().decode(ChuruLedger.self, from: data) == ledger)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"claimed\":{\"checkIn\":50000}"))  // an object, not an array of pairs
    }

    @Test func spendingKeepsTheMissionFields() {
        var ledger = ChuruLedger(installedAt: at(12, 0))
        let snapshot = ledger.apply([usage(at(12, 9), 10_000)], now: at(12, 10), rules: rules, calendar: seoul)
        let spent = snapshot.spending(1_000)
        #expect(spent.missions == snapshot.missions)
        #expect(spent.todayBonus == snapshot.todayBonus)
        #expect(spent.missionMultiplier == snapshot.missionMultiplier)
    }

    // MARK: Tracker missions

    private func missionTracker(in dir: URL) -> (ChuruTracker, JSONFile<ChuruLedger>) {
        let file = JSONFile<ChuruLedger>(url: dir.appendingPathComponent("churu.json"))
        let tracker = ChuruTracker(reader: TokenUsageReader(roots: .init(claude: [], codex: [])),
                                   file: file, rules: rules, calendar: seoul)
        return (tracker, file)
    }

    @Test func recordBeforeAnyRefreshIsIgnored() throws {
        let (tracker, file) = missionTracker(in: try makeTempDirectory())
        #expect(tracker.record(.pet, now: at(12, 10)) == nil)
        #expect(file.load() == nil)
    }

    @Test func recordSavesOnceAndPublishesTheClaimableMission() throws {
        let (tracker, file) = missionTracker(in: try makeTempDirectory())
        _ = tracker.refresh(now: at(12, 10))
        let first = tracker.record(.pet, now: at(12, 11))
        #expect(first?.missions[1].state == .claimable)
        #expect(file.load()?.missionDay?.counts == ["pet": 1])
        // Stamp the file; a second pet past the target must not write it again.
        try FileManager.default.setAttributes([.modificationDate: at(1, 0)], ofItemAtPath: file.url.path)
        let second = tracker.record(.pet, now: at(12, 12))
        #expect(second?.missions[1].progress == 1)
        let modified = try #require(try FileManager.default.attributesOfItem(atPath: file.url.path)[.modificationDate] as? Date)
        #expect(modified == at(1, 0))
    }

    @Test func claimRefreshesPaysAndPersists() throws {
        let (tracker, file) = missionTracker(in: try makeTempDirectory())
        _ = tracker.refresh(now: at(12, 10))
        let paid = tracker.claim(.checkIn, now: at(12, 11))
        #expect(paid.balance == 50_000)
        #expect(paid.missions[0].state == .claimed(reward: 50_000))
        #expect(file.load()?.missionDay?.claimed == ["checkIn": 50_000])
        let again = tracker.claim(.checkIn, now: at(12, 12))
        #expect(again.balance == 50_000)
    }

    /// A pet after midnight, before the first refresh of the new day, publishes nothing: the cached tokens are
    /// yesterday's and the day has not rolled, so a snapshot now would show a wrong balance.
    @Test func recordAfterMidnightWaitsForTheNextRefresh() throws {
        let (tracker, file) = missionTracker(in: try makeTempDirectory())
        _ = tracker.refresh(now: at(12, 23, 59))
        _ = tracker.claim(.checkIn, now: at(12, 23, 59))
        #expect(tracker.record(.pet, now: at(13, 0, 1)) == nil)
        #expect(file.load()?.missionDay?.day == "2026-10-12")
        let rolled = tracker.refresh(now: at(13, 0, 2))
        #expect(rolled.balance == 50_000)
        #expect(tracker.record(.pet, now: at(13, 0, 3))?.missions[1].state == .claimable)
    }

    /// A claim after midnight lands on the new day: the old day's unclaimed check-in is gone.
    @Test func claimAfterMidnightRollsTheDayFirst() throws {
        let (tracker, _) = missionTracker(in: try makeTempDirectory())
        _ = tracker.refresh(now: at(12, 23, 59))
        let paid = tracker.claim(.checkIn, now: at(13, 0, 1))
        #expect(paid.day == "2026-10-13")
        #expect(paid.balance == 50_000)
        #expect(tracker.ledger?.missionDay?.day == "2026-10-13")
    }
}
