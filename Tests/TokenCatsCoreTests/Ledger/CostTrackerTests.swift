import Foundation
import Testing
@testable import TokenCatsCore

struct CostTrackerTests {
    @Test func separatesTodayAndRollingWeekByProvider() throws {
        let root = try makeTempDirectory()
        let pricesURL = resourcesURL
            .appendingPathComponent("model-prices.json")
        let catalog = try PriceCatalog(data: Data(contentsOf: pricesURL))
        let claudeFolder = root.appendingPathComponent("claude/p")
        try FileManager.default.createDirectory(at: claudeFolder, withIntermediateDirectories: true)
        let claude = """
        {"type":"assistant","requestId":"r1","timestamp":"2026-10-09T10:00:00Z","message":{"id":"c1","model":"claude-opus-5-5","usage":{"input_tokens":1000000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
        {"type":"assistant","requestId":"r2","timestamp":"2026-10-10T10:00:00Z","message":{"id":"c2","model":"claude-opus-5-5","usage":{"input_tokens":1000000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
        """
        try (claude + "\n").write(to: claudeFolder.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)
        let reader = TokenUsageReader(roots: .init(claude: [root.appendingPathComponent("claude")], codex: []))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let tracker = CostTracker(reader: reader, catalog: catalog, calendar: calendar)
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 22))!
        let snapshot = tracker.refresh(now: now)
        #expect(snapshot.today[.claude]?.tokens == 1_000_000)
        #expect(snapshot.week[.claude]?.tokens == 2_000_000)
        #expect(snapshot.todayTotal.estimate.label == "$4.00")
        #expect(snapshot.weekTotal.estimate.label == "$8.00")
        #expect(snapshot.dailyByProvider["2026-10-09"] == [.claude: 1_000_000])
        #expect(snapshot.dailyByProvider["2026-10-10"] == [.claude: 1_000_000])
    }
}
