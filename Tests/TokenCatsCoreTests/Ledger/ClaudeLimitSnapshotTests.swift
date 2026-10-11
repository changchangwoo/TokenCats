import Foundation
import Testing
@testable import TokenCatsCore

struct ClaudeLimitSnapshotTests {
    @Test func readsBothWindows() throws {
        let data = Data(#"{"updated_at":1800000000,"five_hour":{"used_percentage":42,"resets_at":1800005400},"seven_day":{"used_percentage":84.5,"resets_at":1800172800}}"#.utf8)
        let reading = try #require(ClaudeLimitSnapshot.reading(from: data))
        #expect(reading.provider == .claude)
        #expect(reading.observedAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(reading.windows == [
            LimitWindow(kind: .fiveHour, usedPercent: 42, resetsAt: Date(timeIntervalSince1970: 1_800_005_400)),
            LimitWindow(kind: .weekly, usedPercent: 84.5, resetsAt: Date(timeIntervalSince1970: 1_800_172_800)),
        ])
    }

    @Test func oneWindowIsEnough() throws {
        let data = Data(#"{"updated_at":1800000000,"seven_day":{"used_percentage":10,"resets_at":1800172800}}"#.utf8)
        #expect(try #require(ClaudeLimitSnapshot.reading(from: data)).windows.map(\.kind) == [.weekly])
    }

    @Test func brokenFileIsNil() {
        #expect(ClaudeLimitSnapshot.reading(from: Data("not json".utf8)) == nil)
        #expect(ClaudeLimitSnapshot.reading(from: Data(#"{"five_hour":{}}"#.utf8)) == nil)
        #expect(ClaudeLimitSnapshot.read(url: URL(fileURLWithPath: "/nonexistent/claude-limits.json")) == nil)
    }
}
