import Foundation
import Testing
@testable import TokenCatsCore

private let seoul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}()

private func claudeLine(_ id: String, _ stamp: String, output: Int) -> String {
    #"{"type":"assistant","timestamp":"\#(stamp)","requestId":"r-\#(id)","message":{"id":"\#(id)","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":\#(output),"cache_read_input_tokens":0}}}"#
}
private func codexLine(_ stamp: String, input: Int) -> String {
    #"{"timestamp":"\#(stamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":\#(input),"cached_input_tokens":0,"output_tokens":0}}}}"#
}

struct DailyTokenScanTests {
    private func roots(_ folder: URL) -> TokenUsageReader.Roots {
        TokenUsageReader.Roots(claude: [folder.appendingPathComponent("claude")], codex: [folder.appendingPathComponent("codex")])
    }
    private func write(_ lines: [String], _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    @Test func claudeDuplicatesCountOnceAtTheirLargestAndCodexAddsUp() throws {
        let folder = try makeTempDirectory()
        try write([claudeLine("m1", "2026-10-09T01:00:00.000Z", output: 10),
                   claudeLine("m1", "2026-10-09T01:00:01.000Z", output: 40)],
                  folder.appendingPathComponent("claude/p/a.jsonl"))
        try write([claudeLine("m1", "2026-10-09T01:00:02.000Z", output: 30)],
                  folder.appendingPathComponent("claude/p/b.jsonl"))
        try write([codexLine("2026-10-09T02:00:00.000Z", input: 100), codexLine("2026-10-09T16:00:00.000Z", input: 5)],
                  folder.appendingPathComponent("codex/2026/10/09/rollout.jsonl"))
        let days = DailyTokenScan.scan(roots: roots(folder), calendar: seoul)
        #expect(days == ["2026-10-09": 140, "2026-10-10": 5])
    }

    @Test func linesAcrossChunkBoundariesCountOnce() throws {
        let folder = try makeTempDirectory()
        let lines = (0..<20).map { codexLine("2026-10-09T02:00:00.000Z", input: $0 + 1) }
        try write(lines, folder.appendingPathComponent("codex/x.jsonl"))
        for chunk in [7, 64, 1_000_000] {
            #expect(DailyTokenScan.scan(roots: roots(folder), calendar: seoul, chunkSize: chunk) == ["2026-10-09": 210])
        }
    }

    @Test func mergeTakesTheLargerValuePerDayAndScansOnce() throws {
        let folder = try makeTempDirectory()
        let history = JSONFile<DailyHistory>(url: folder.appendingPathComponent("daily-history.json"))
        let ledgerFile = JSONFile<ChuruLedger>(url: folder.appendingPathComponent("churu.json"))
        var ledger = ChuruLedger(installedAt: seoul.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 15))!)
        _ = ledger.apply([TokenEntry(provider: .claude, key: "k", timestamp: seoul.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 16))!,
                                     processed: 300, cacheRead: 0)],
                         now: seoul.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 9))!, calendar: seoul)
        ledgerFile.save(ledger)
        var scans = 0
        let now = seoul.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 9))!
        let merged = ProfileHistory.dailyTokens(history: history, ledger: ledgerFile, today: now, todayTokens: 70,
                                                calendar: seoul, now: now) {
            scans += 1
            return ["2026-10-08": 1_000, "2026-10-09": 500, "2026-10-10": 20]
        }
        #expect(merged == ["2026-10-08": 1_000, "2026-10-09": 500, "2026-10-10": 70])
        _ = ProfileHistory.dailyTokens(history: history, ledger: ledgerFile, today: now, todayTokens: 70,
                                       calendar: seoul, now: now) { scans += 1; return [:] }
        #expect(scans == 1)
        let beforeLiveCount = ProfileHistory.dailyTokens(history: history, ledger: ledgerFile, today: now,
                                                         todayTokens: 0, calendar: seoul, now: now) {
            scans += 1
            return [:]
        }
        #expect(beforeLiveCount["2026-10-10"] == 70)
        #expect(WeekUsage.make(dailyTokens: beforeLiveCount, today: now, calendar: seoul).total == 1_570)
        #expect(scans == 1)
    }
}
