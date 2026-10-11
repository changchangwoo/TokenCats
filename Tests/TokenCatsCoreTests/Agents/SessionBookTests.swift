import Foundation
import Testing
@testable import TokenCatsCore

func envelope(
    _ event: String, session: String = "s1", provider: AgentProvider = .claude,
    tool: String? = nil, ts: Double, terminal: String? = nil
) -> HookEnvelope {
    HookEnvelope(
        provider: provider, sessionId: session, event: event, cwd: "/Users/me/proj",
        tool: tool, toolSummary: tool.map { "\($0) summary" }, orcaTerminal: terminal, ts: ts, hookPpid: nil)
}

struct SessionBookTests {
    @Test func decodesScriptPayload() throws {
        let json = #"{"provider":"codex","session_id":"x","event":"Stop","cwd":"/a","tool":null,"tool_summary":"","orca_terminal":"term_1","ts":12.5}"#
        let decoded = try JSONDecoder().decode(HookEnvelope.self, from: Data(json.utf8))
        #expect(decoded.provider == .codex)
        #expect(decoded.orcaTerminal == "term_1")
        #expect(decoded.ts == 12.5)
    }

    @Test func fullTurnLifecycle() {
        var book = SessionBook()
        book.apply(envelope("SessionStart", ts: 1, terminal: "term_1"))
        #expect(book.orderedSessions[0].state == .idle)
        #expect(book.orderedSessions[0].orcaTerminal == "term_1")
        #expect(book.orderedSessions[0].folderName == "proj")
        book.apply(envelope("UserPromptSubmit", ts: 2))
        #expect(book.orderedSessions[0].state == .working)
        book.apply(envelope("PermissionRequest", tool: "Bash", ts: 3))
        #expect(book.orderedSessions[0].state == .needsApproval)
        book.apply(envelope("PostToolUse", tool: "Bash", ts: 4))
        #expect(book.orderedSessions[0].state == .working)
        book.apply(envelope("Stop", ts: 5))
        #expect(book.orderedSessions[0].state == .turnDone)
        book.apply(envelope("SessionEnd", ts: 6))
        #expect(book.orderedSessions.isEmpty)
    }

    @Test func lateEventsAreIgnored() {
        var book = SessionBook()
        book.apply(envelope("Stop", ts: 10))
        book.apply(envelope("PreToolUse", tool: "Read", ts: 9))
        #expect(book.orderedSessions[0].state == .turnDone)
    }

    @Test func providersWithSameSessionIdDoNotCollide() {
        var book = SessionBook()
        book.apply(envelope("UserPromptSubmit", provider: .claude, ts: 1))
        book.apply(envelope("Stop", provider: .codex, ts: 1))
        #expect(book.orderedSessions.count == 2)
    }

    @Test func moodPriorityAndOrdering() {
        var book = SessionBook()
        #expect(book.mood == .idle)
        book.apply(envelope("Stop", session: "a", ts: 1))
        #expect(book.mood == .done)
        book.apply(envelope("UserPromptSubmit", session: "b", ts: 2))
        #expect(book.mood == .working)
        book.apply(envelope("PermissionRequest", session: "c", tool: "Bash", ts: 3))
        #expect(book.mood == .needsApproval)
        // Unseen completions are "my turn" and rank above running work
        #expect(book.orderedSessions.map(\.sessionId) == ["c", "a", "b"])
    }

    @Test func longSilenceDoesNotChangeStateOfTrackedAgents() {
        var book = SessionBook()
        book.apply(envelope("UserPromptSubmit", ts: 0), agent: AgentIdentity(pid: 9, startedAt: "s"))
        book.markStale(now: 3 * 3600)
        #expect(book.orderedSessions[0].state == .working)
        book.markStale(now: 7 * 3600)
        #expect(book.orderedSessions.count == 1)  // tracked agents are only removed by the liveness check
    }

    @Test func untrackedSessionsDropAfterSixHours() {
        var book = SessionBook()
        book.apply(envelope("UserPromptSubmit", ts: 0))
        book.markStale(now: 3 * 3600)
        #expect(book.orderedSessions[0].state == .working)
        book.markStale(now: 7 * 3600)
        #expect(book.orderedSessions.isEmpty)
    }

    @Test func firstEventRecordsAgentIdentity() {
        var book = SessionBook()
        let agent = AgentIdentity(pid: 42, startedAt: "100.000001")
        book.apply(envelope("SessionStart", ts: 1), agent: agent)
        book.apply(envelope("UserPromptSubmit", ts: 2), agent: AgentIdentity(pid: 99, startedAt: "x"))
        #expect(book.orderedSessions[0].agent == agent)
    }

    @Test func deadAgentsAreRemoved() {
        var book = SessionBook()
        book.apply(envelope("PermissionRequest", session: "dead", tool: "Bash", ts: 1), agent: AgentIdentity(pid: 1, startedAt: "a"))
        book.apply(envelope("UserPromptSubmit", session: "alive", ts: 1), agent: AgentIdentity(pid: 2, startedAt: "b"))
        book.apply(envelope("UserPromptSubmit", session: "unknown-agent", ts: 1))
        book.removeDead { $0.pid == 2 }
        #expect(Set(book.orderedSessions.map(\.sessionId)) == ["alive", "unknown-agent"])
    }

    @Test func preToolUseRecordsCurrentActivity() {
        var book = SessionBook()
        book.apply(envelope("UserPromptSubmit", ts: 1))
        book.apply(envelope("PreToolUse", tool: "Edit", ts: 2))
        #expect(book.orderedSessions[0].currentTool == "Edit")
        #expect(book.orderedSessions[0].currentSummary == "Edit summary")
    }

    @Test func stateSinceChangesOnlyWithState() {
        var book = SessionBook()
        book.apply(envelope("UserPromptSubmit", ts: 2))
        book.apply(envelope("PreToolUse", tool: "Read", ts: 3))
        #expect(book.orderedSessions[0].stateSince == 2)
        book.apply(envelope("Stop", ts: 5))
        #expect(book.orderedSessions[0].stateSince == 5)
    }

    @Test func completionIsUnseenUntilSeenOrNextPrompt() {
        var book = SessionBook()
        book.apply(envelope("UserPromptSubmit", ts: 1))
        #expect(!book.orderedSessions[0].unseenDone)
        book.apply(envelope("Stop", ts: 2))
        #expect(book.orderedSessions[0].unseenDone)
        book.syncUnseen([])
        #expect(!book.orderedSessions[0].unseenDone)
        book.apply(envelope("Stop", ts: 3))
        book.apply(envelope("UserPromptSubmit", ts: 4))
        #expect(!book.orderedSessions[0].unseenDone)
        #expect(book.orderedSessions[0].currentTool == nil)
    }

    @Test func seenCompletionsRankBelowRunningWork() {
        var book = SessionBook()
        book.apply(envelope("Stop", session: "done", ts: 1))
        book.syncUnseen([])
        book.apply(envelope("UserPromptSubmit", session: "run", ts: 1))
        #expect(book.orderedSessions.map(\.sessionId) == ["run", "done"])
    }

    @Test func summaryCountsWhatNeedsMe() {
        var book = SessionBook()
        book.apply(envelope("UserPromptSubmit", session: "a", ts: 1))
        book.apply(envelope("UserPromptSubmit", session: "b", ts: 1))
        book.apply(envelope("PermissionRequest", session: "c", tool: "Bash", ts: 1))
        book.apply(envelope("Stop", session: "d", ts: 1))
        book.apply(envelope("Stop", session: "e", ts: 1))
        book.syncUnseen(["claude:d"])
        #expect(book.summary == SessionSummary(working: 2, needsApproval: 1, unseenDone: 1))
    }
}

