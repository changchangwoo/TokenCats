import Foundation
import Testing
@testable import TokenCatsCore

private func claudeLine(id: String?, request: String = "req", ts: String = "2026-10-09T10:00:00.123Z",
                        input: Int = 10, cacheWrite: Int = 100, output: Int = 5, cacheRead: Int = 1_000,
                        iterations: String = "", type: String = "assistant") -> String {
    let idField = id.map { "\"id\":\"\($0)\"," } ?? ""
    let iterationsField = iterations.isEmpty ? "" : ",\"iterations\":[\(iterations)]"
    return """
    {"type":"\(type)","requestId":"\(request)","uuid":"u-\(UUID().uuidString)","timestamp":"\(ts)","message":{\(idField)"model":"m","usage":{"input_tokens":\(input),"cache_creation_input_tokens":\(cacheWrite),"output_tokens":\(output),"cache_read_input_tokens":\(cacheRead)\(iterationsField)}}}
    """
}

private func codexLine(ts: String = "2026-10-09T10:00:00.500Z", input: Int, cached: Int, output: Int, total: Int = 999_999) -> String {
    """
    {"timestamp":"\(ts)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(total),"cached_input_tokens":0,"output_tokens":0},"last_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cached),"output_tokens":\(output)}}}}
    """
}

private struct Fixture {
    let root: URL
    let reader: TokenUsageReader

    init() throws {
        root = try makeTempDirectory()
        reader = TokenUsageReader(roots: .init(claude: [root.appendingPathComponent("claude")],
                                               codex: [root.appendingPathComponent("codex")]))
    }

    func write(_ path: String, _ lines: [String], newline: Bool = true) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + (newline ? "\n" : "")).write(to: url, atomically: true, encoding: .utf8)
    }

    func append(_ path: String, _ text: String) throws {
        let handle = try FileHandle(forWritingTo: root.appendingPathComponent(path))
        try handle.seekToEnd()
        handle.write(Data(text.utf8))
        try handle.close()
    }

    func read() -> [TokenEntry] { reader.entries(modifiedSince: .distantPast) }
}

struct TokenUsageReaderTests {
    @Test func countsUncachedInputCacheWritesAndOutputButNotCacheReads() throws {
        let f = try Fixture()
        try f.write("claude/p/s.jsonl", [claudeLine(id: "m1", input: 10, cacheWrite: 100, output: 5, cacheRead: 1_000)])
        let entries = f.read()
        #expect(entries.count == 1)
        #expect(entries[0].processed == 115)
        #expect(entries[0].cacheRead == 1_000)
        #expect(entries[0].timestamp == TokenLogParser.parseTimestamp("2026-10-09T10:00:00.123Z"))
    }

    @Test func keepsTheLargestOfDuplicatedStreamingLines() throws {
        let f = try Fixture()
        try f.write("claude/p/s.jsonl", [
            claudeLine(id: "m1", ts: "2026-10-09T10:00:01Z", output: 5),
            claudeLine(id: "m1", ts: "2026-10-09T10:00:02Z", output: 500),
            claudeLine(id: "m1", ts: "2026-10-09T10:00:03Z", output: 200),
        ])
        let entries = f.read()
        #expect(entries.count == 1)
        #expect(entries[0].processed == 10 + 100 + 500)
        #expect(entries[0].timestamp == TokenLogParser.parseTimestamp("2026-10-09T10:00:01Z"))
    }

    @Test func dedupsAcrossFilesIncludingSubagentLogs() throws {
        let f = try Fixture()
        try f.write("claude/p/s.jsonl", [claudeLine(id: "m1"), claudeLine(id: "m2", request: "r2")])
        try f.write("claude/p/s/subagents/agent-a.jsonl", [claudeLine(id: "m1"), claudeLine(id: "m3", request: "r3")])
        #expect(f.read().count == 3)
    }

    @Test func addsAdvisorIterationsButNotTheMainMessageIteration() throws {
        let f = try Fixture()
        let iterations = """
        {"type":"message","input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000},\
        {"type":"advisor_message","input_tokens":40000,"output_tokens":900,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}
        """
        try f.write("claude/p/s.jsonl", [claudeLine(id: "m1", iterations: iterations)])
        #expect(f.read().first?.processed == 115 + 40_900)
    }

    @Test func ignoresLinesThatAreNotAssistantUsage() throws {
        let f = try Fixture()
        try f.write("claude/p/s.jsonl", [
            claudeLine(id: "m1", type: "user"),
            #"{"type":"assistant","message":{"usage":{"input_tokens":1}}}"#,  // no timestamp
            "not json \"usage\"",
        ])
        #expect(f.read().isEmpty)
    }

    @Test func readsOnlyAppendedLinesAndWaitsForAnUnfinishedLine() throws {
        let f = try Fixture()
        try f.write("claude/p/s.jsonl", [claudeLine(id: "m1")])
        #expect(f.read().count == 1)
        let partial = claudeLine(id: "m2", request: "r2")
        try f.append("claude/p/s.jsonl", String(partial.prefix(40)))
        #expect(f.read().count == 1)
        try f.append("claude/p/s.jsonl", String(partial.dropFirst(40)) + "\n")
        #expect(f.read().count == 2)
        #expect(f.read().count == 2)
    }

    @Test func rereadsAFileThatShrank() throws {
        let f = try Fixture()
        try f.write("claude/p/s.jsonl", [claudeLine(id: "m1"), claudeLine(id: "m2", request: "r2")])
        #expect(f.read().count == 2)
        try f.write("claude/p/s.jsonl", [claudeLine(id: "m9", request: "r9")])
        let entries = f.read()
        #expect(entries.count == 1)
        #expect(entries[0].key == "m9:r9")
    }

    @Test func sumsCodexTurnDeltasAndSubtractsCachedInput() throws {
        let f = try Fixture()
        try f.write("codex/2026/10/09/rollout-a.jsonl", [
            codexLine(input: 1_000, cached: 800, output: 50),
            codexLine(input: 2_000, cached: 1_500, output: 70),
            #"{"timestamp":"2026-10-09T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":null}}"#,
        ])
        let entries = f.read()
        #expect(entries.count == 2)
        #expect(entries.map(\.processed).reduce(0, +) == 250 + 570)
        #expect(entries.allSatisfy { $0.provider == .codex })
    }

    @Test func costBucketsFollowTheRecordedModelAndCacheTypes() throws {
        let f = try Fixture()
        let claude = """
        {"type":"assistant","requestId":"r","timestamp":"2026-10-09T10:00:00Z","message":{"id":"c1","model":"claude-opus-5-5","usage":{"input_tokens":10,"cache_creation_input_tokens":70,"cache_creation":{"ephemeral_5m_input_tokens":20,"ephemeral_1h_input_tokens":50},"cache_read_input_tokens":100,"output_tokens":5}}}
        """
        try f.write("claude/p/s.jsonl", [claude])
        try f.write("codex/2026/10/09/rollout-a.jsonl", [
            #"{"timestamp":"2026-10-09T09:59:00Z","type":"turn_context","payload":{"model":"gpt-6-sol"}}"#,
            #"{"timestamp":"2026-10-09T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"cached_input_tokens":600,"cache_write_input_tokens":100,"output_tokens":50}}}}"#,
        ])
        let entries = f.read()
        let claudeUsage = try #require(entries.first(where: { $0.provider == .claude })?.billing.first)
        #expect(claudeUsage.model == "claude-opus-5-5")
        #expect(claudeUsage.cacheWrite5m == 20 && claudeUsage.cacheWrite1h == 50)
        #expect(claudeUsage.cachedInput == 100)
        let codexUsage = try #require(entries.first(where: { $0.provider == .codex })?.billing.first)
        #expect(codexUsage.model == "gpt-6-sol")
        #expect(codexUsage.input == 300 && codexUsage.cachedInput == 600)
        #expect(codexUsage.cacheWrite5m == 100 && codexUsage.output == 50)
    }

    @Test func skipsFilesNotModifiedSinceTheWindow() throws {
        let f = try Fixture()
        try f.write("claude/p/s.jsonl", [claudeLine(id: "m1")])
        #expect(f.reader.entries(modifiedSince: Date().addingTimeInterval(3_600)).isEmpty)
    }

    /// Compares the Swift reader with the validated probe script on real logs. Run with CHURU_LIVE=1.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CHURU_LIVE"] == "1"))
    func printsDailyTotalsFromRealLogs() {
        let since = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 28))!
        var byDay: [String: [TokenProvider: Int]] = [:]
        for entry in TokenUsageReader().entries(modifiedSince: since) where entry.timestamp >= since {
            byDay[ChuruLedger.dayKey(entry.timestamp, .current), default: [:]][entry.provider, default: 0] += entry.processed
        }
        for day in byDay.keys.sorted() {
            let p = byDay[day]!
            print("LIVE \(day) claude=\(p[.claude] ?? 0) codex=\(p[.codex] ?? 0) total=\(p.values.reduce(0, +))")
        }
    }
}
