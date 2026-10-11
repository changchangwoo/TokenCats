import Foundation
import Testing
@testable import TokenCatsCore

private func session(_ id: String, _ state: AgentState, unseen: Bool = false, ts: Double = 1) -> AgentSession {
    var s = AgentSession(provider: .claude, sessionId: id, cwd: "/Users/me/\(id)", state: state, orcaTerminal: "term_\(id)", lastEventAt: ts)
    s.unseenDone = unseen
    s.terminalTitle = "title \(id)"
    return s
}

struct RecentResultsTests {
    @Test func recordsOneResultPerSessionNewestFirst() {
        var results = RecentResults()
        results.record(session("a", .turnDone), outcome: .success, at: Date(timeIntervalSince1970: 1))
        results.record(session("b", .error), outcome: .error, at: Date(timeIntervalSince1970: 2))
        results.record(session("a", .turnDone), outcome: .success, at: Date(timeIntervalSince1970: 3))
        #expect(results.items.map(\.id) == ["claude:a", "claude:b"])
        #expect(results.items[0].title == "title a")
        #expect(results.items[0].folder == "a")
        #expect(results.items[0].orcaTerminal == "term_a")
        #expect(results.unseenIds == ["claude:a", "claude:b"])
    }

    @Test func markSeenClearsOnlyThatResult() {
        var results = RecentResults()
        results.record(session("a", .turnDone), outcome: .success, at: Date())
        let marked = results.markSeen("claude:a")
        let missing = results.markSeen("claude:zzz")
        #expect(marked)
        #expect(!missing)
        #expect(results.unseenIds.isEmpty)
        #expect(results.items.count == 1)
    }

    @Test func keepsAtMostTwentyAndSevenDays() {
        var results = RecentResults()
        for i in 0..<25 { results.record(session("s\(i)", .turnDone), outcome: .success, at: Date(timeIntervalSince1970: Double(i))) }
        #expect(results.items.count == 20)
        #expect(results.items.first?.id == "claude:s24")
        results.prune(now: Date(timeIntervalSince1970: 24 + 7 * 86400 + 1))
        #expect(results.items.isEmpty)
    }
}

private let day = 86400.0

struct HomeRowsTests {
    @Test func idleSessionFallsAsleepAfterADayOfSilence() {
        let now = 10 * day
        #expect(HomeRows.isAsleep(session("a", .idle, ts: now - 25 * 3600), now: now))
        #expect(!HomeRows.isAsleep(session("a", .idle, ts: now - 23 * 3600), now: now))
        #expect(HomeRows.isAsleep(session("a", .unknown, ts: now - 2 * day), now: now))
        #expect(HomeRows.isAsleep(session("a", .turnDone, ts: now - 2 * day), now: now))
    }

    @Test func sessionsThatWantTheUserOrWorkNeverSleep() {
        let now = 10 * day
        let old = now - 5 * day
        for s in [session("w", .working, ts: old), session("n", .needsApproval, ts: old), session("e", .error, ts: old),
                  session("u", .idle, unseen: true, ts: old)] {
            #expect(!HomeRows.isAsleep(s, now: now))
        }
    }

    @Test func stripOrdersAwakeByUrgencyThenRecencyThenSleepers() {
        let now = 10 * day
        let sessions = [
            session("sleepy", .idle, ts: now - 3 * day),
            session("idleOld", .idle, ts: now - 600),
            session("idleNew", .idle, ts: now - 60),
            session("w", .working, ts: now - 900),
            session("u", .idle, unseen: true, ts: now - 50),
            session("e", .error, ts: now - 10),
            session("n", .needsApproval, ts: now - 5),
        ]
        let rows = HomeRows.strip(sessions: sessions, results: [], now: now)
        #expect(rows.map(\.id) == ["claude:n", "claude:e", "claude:u", "claude:w", "claude:idleNew", "claude:idleOld", "claude:sleepy"])
    }

    @Test func stripKeepsUnseenResultsOfEndedSessionsOnly() {
        var results = RecentResults()
        results.record(session("gone", .turnDone), outcome: .success, at: Date(timeIntervalSince1970: 2))
        results.record(session("seen", .turnDone), outcome: .success, at: Date(timeIntervalSince1970: 1))
        _ = results.markSeen("claude:seen")
        let live = session("a", .turnDone, unseen: true)
        results.record(live, outcome: .success, at: Date(timeIntervalSince1970: 3))
        let rows = HomeRows.strip(sessions: [live, session("w", .working)], results: results.items, now: 10)
        #expect(Set(rows.map(\.id)) == ["claude:a", "claude:gone", "claude:w"])
        #expect(rows.last?.id == "claude:w")
    }

    @Test func liveSessionAndItsResultAreOneRow() {
        let live = session("a", .turnDone, unseen: true)
        var results = RecentResults()
        results.record(live, outcome: .success, at: Date())
        #expect(HomeRows.strip(sessions: [live], results: results.items, now: 1).map(\.id) == ["claude:a"])
    }
}
