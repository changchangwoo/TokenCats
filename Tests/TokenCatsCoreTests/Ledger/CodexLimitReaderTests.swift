import Foundation
import Testing
@testable import TokenCatsCore

private func tokenCount(_ stamp: String, _ limits: String) -> String {
    #"{"timestamp":"\#(stamp)","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":\#(limits)}}"#
}
private let weekly = #"{"primary":{"used_percent":47.0,"window_minutes":10080,"resets_at":1800172800},"secondary":null}"#
private let both = #"{"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":1800005400},"secondary":{"used_percent":30.0,"window_minutes":10080,"resets_at":1800172800}}"#

private func write(_ lines: [String], _ root: URL, _ day: String, _ name: String, modified: Date) throws {
    let folder = root.appendingPathComponent(day, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent(name)
    try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: file.path)
}

struct CodexLimitReaderTests {
    @Test func classifiesWindowsByLength() {
        #expect(CodexLimitReader.windowKind(minutes: 300) == .fiveHour)
        #expect(CodexLimitReader.windowKind(minutes: 10_080) == .weekly)
        #expect(CodexLimitReader.windowKind(minutes: 1_440) == .hours(24))
    }

    @Test func readsPrimaryAndSecondaryFromTheLastEvent() throws {
        let root = try makeTempDirectory()
        try write([tokenCount("2026-10-10T01:00:00.000Z", weekly), tokenCount("2026-10-10T02:00:00.000Z", both)],
                  root, "2026/10/10", "rollout-a.jsonl", modified: Date())
        let reading = try #require(CodexLimitReader(sessionsRoot: root).latest())
        #expect(reading.provider == .codex)
        #expect(reading.windows.map(\.kind) == [.fiveHour, .weekly])
        #expect(reading.windows.map(\.usedPercent) == [12, 30])
        #expect(reading.observedAt == TokenLogParser.parseTimestamp("2026-10-10T02:00:00.000Z"))
    }

    @Test func skipsNullRateLimitsAndUsesTheEarlierOne() throws {
        let root = try makeTempDirectory()
        try write([tokenCount("2026-10-10T01:00:00.000Z", weekly), tokenCount("2026-10-10T02:00:00.000Z", "null")],
                  root, "2026/10/10", "rollout-a.jsonl", modified: Date())
        #expect(try #require(CodexLimitReader(sessionsRoot: root).latest()).windows.map(\.usedPercent) == [47])
    }

    @Test func newestFileWinsAndOlderDaysAreAFallback() throws {
        let root = try makeTempDirectory()
        try write([tokenCount("2026-10-09T01:00:00.000Z", weekly)], root, "2026/10/09", "rollout-old.jsonl",
                  modified: Date(timeIntervalSinceNow: -86_400))
        try write([tokenCount("2026-10-10T01:00:00.000Z", both)], root, "2026/10/10", "rollout-new.jsonl",
                  modified: Date())
        #expect(try #require(CodexLimitReader(sessionsRoot: root).latest()).windows.count == 2)
        try write([#"{"type":"session_meta"}"#], root, "2026/10/10", "rollout-new.jsonl", modified: Date())
        #expect(try #require(CodexLimitReader(sessionsRoot: root).latest()).windows.map(\.usedPercent) == [47])
    }

    @Test func findsTheLastEventInTheTailOfALongFile() throws {
        let root = try makeTempDirectory()
        let filler = (0..<4_000).map { #"{"type":"response_item","payload":{"text":"\#($0) \#(String(repeating: "x", count: 100))"}}"# }
        try write([tokenCount("2026-10-10T01:00:00.000Z", both)] + filler + [tokenCount("2026-10-10T03:00:00.000Z", weekly)],
                  root, "2026/10/10", "rollout-a.jsonl", modified: Date())
        #expect(try #require(CodexLimitReader(sessionsRoot: root).latest()).windows.map(\.usedPercent) == [47])
    }

    @Test func noSessionsIsNil() throws {
        #expect(CodexLimitReader(sessionsRoot: try makeTempDirectory()).latest() == nil)
    }
}
