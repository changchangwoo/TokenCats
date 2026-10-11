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
}
