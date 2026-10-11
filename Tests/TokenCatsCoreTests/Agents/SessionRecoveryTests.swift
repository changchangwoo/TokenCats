import Foundation
import Testing
@testable import TokenCatsCore

private func proc(_ name: String, started: String = "t0", cwd: String = "/Users/me/proj") -> ProcessDetail {
    ProcessDetail(tty: "ttys001", startedAt: started, command: name, cwd: cwd, parentPid: 1, name: name)
}

private func snapshot(_ id: String, pid: Int32, started: String = "t0", lastEventAt: Double = 1) -> SessionSnapshot {
    var s = AgentSession(provider: .claude, sessionId: id, cwd: "/Users/me/proj", state: .working, orcaTerminal: "term_1", lastEventAt: lastEventAt)
    s.agent = AgentIdentity(pid: pid, startedAt: started)
    s.terminalTitle = "saved title"
    return SessionSnapshot(s)!
}

struct SessionRecoveryTests {
    @Test func liveSnapshotIsRestoredAsUnknown() throws {
        let inspector = FakeInspector([100: proc("claude")])
        let recovery = SessionRecovery(inspector: inspector, claudeSessionsDirectory: try makeTempDirectory())
        let result = recovery.recover(snapshots: [snapshot("a", pid: 100)])
        #expect(result.count == 1)
        #expect(result[0].id == "claude:a")
        #expect(result[0].state == .unknown)
        #expect(result[0].terminalTitle == "saved title")
        #expect(result[0].orcaTerminal == "term_1")
    }

    @Test func snapshotWithReusedPidIsDropped() throws {
        let inspector = FakeInspector([100: proc("claude", started: "t1")])
        let recovery = SessionRecovery(inspector: inspector, claudeSessionsDirectory: try makeTempDirectory())
        // Stage 2 finds pid 100 too, but there is no sessions file for it.
        #expect(recovery.recover(snapshots: [snapshot("a", pid: 100, started: "t0")]).isEmpty)
    }

    @Test func claudeSessionFileFindsSessionsStartedWhileAppWasOff() throws {
        let dir = try makeTempDirectory()
        try Data(#"{"pid":200,"sessionId":"b","cwd":"/Users/me/web","status":"busy","extra":1}"#.utf8)
            .write(to: dir.appendingPathComponent("200.json"))
        let inspector = FakeInspector([200: proc("claude")])
        inspector.environments[200] = ["ORCA_TERMINAL_HANDLE": "term_9"]
        let file = dir.appendingPathComponent("200.json").path
        let result = SessionRecovery(inspector: inspector, claudeSessionsDirectory: dir, modifiedAt: { $0 == file ? 500 : nil })
            .recover(snapshots: [])
        #expect(result == [RecoveredSession(
            provider: .claude, sessionId: "b", cwd: "/Users/me/web", agent: AgentIdentity(pid: 200, startedAt: "t0"),
            orcaTerminal: "term_9", terminalTitle: nil, branch: nil, state: .working, lastActivity: 500)])
    }

    @Test func claudeFileWithoutRequiredFieldsIsSkipped() throws {
        let dir = try makeTempDirectory()
        try Data(#"{"pid":200,"status":"idle"}"#.utf8).write(to: dir.appendingPathComponent("200.json"))
        let inspector = FakeInspector([200: proc("claude")])
        #expect(SessionRecovery(inspector: inspector, claudeSessionsDirectory: dir).recover(snapshots: []).isEmpty)
    }

    @Test func claudeFileForNonClaudeProcessIsIgnored() throws {
        let dir = try makeTempDirectory()
        try Data(#"{"pid":300,"sessionId":"c","cwd":"/x","status":"idle"}"#.utf8).write(to: dir.appendingPathComponent("300.json"))
        let inspector = FakeInspector([300: proc("node", cwd: "/x")])
        #expect(SessionRecovery(inspector: inspector, claudeSessionsDirectory: dir).recover(snapshots: []).isEmpty)
    }

    @Test func codexSessionIdComesFromTheOpenRolloutFileName() throws {
        let inspector = FakeInspector([400: proc("codex", cwd: "/Users/me/api")])
        inspector.openFiles[400] = [
            "/dev/null",
            "/Users/me/.codex/sessions/2026/10/09/rollout-2026-10-09T17-07-36-01a11fb4-0fa1-71e3-af5e-cb101960bfae.jsonl",
        ]
        let result = SessionRecovery(inspector: inspector, claudeSessionsDirectory: try makeTempDirectory()).recover(snapshots: [])
        #expect(result.map(\.id) == ["codex:01a11fb4-0fa1-71e3-af5e-cb101960bfae"])
        #expect(result[0].state == .unknown)
        #expect(result[0].cwd == "/Users/me/api")
    }

    @Test func codexLastActivityIsTheRolloutFileTime() throws {
        let rollout = "/Users/me/.codex/sessions/2026/10/09/rollout-2026-10-09T17-07-36-01a11fb4-0fa1-71e3-af5e-cb101960bfae.jsonl"
        let inspector = FakeInspector([400: proc("codex")])
        inspector.openFiles[400] = [rollout]
        let recovery = SessionRecovery(
            inspector: inspector, claudeSessionsDirectory: try makeTempDirectory(), modifiedAt: { $0 == rollout ? 700 : nil })
        #expect(recovery.recover(snapshots: []).first?.lastActivity == 700)
    }

    @Test func snapshotUsesTheLaterOfSavedEventAndClaudeFileTime() throws {
        let dir = try makeTempDirectory()
        let file = dir.appendingPathComponent("100.json").path
        let inspector = FakeInspector([100: proc("claude")])
        let newerFile = SessionRecovery(inspector: inspector, claudeSessionsDirectory: dir, modifiedAt: { $0 == file ? 900 : nil })
        #expect(newerFile.recover(snapshots: [snapshot("a", pid: 100, lastEventAt: 300)]).first?.lastActivity == 900)
        let noFile = SessionRecovery(inspector: inspector, claudeSessionsDirectory: dir, modifiedAt: { _ in nil })
        #expect(noFile.recover(snapshots: [snapshot("a", pid: 100, lastEventAt: 300)]).first?.lastActivity == 300)
    }

    @Test func snapshotsSavedBeforeActivityTimeStillLoad() throws {
        let json = #"[{"provider":"claude","sessionId":"a","cwd":"/p","agentPid":1,"agentStartedAt":"t"}]"#
        let loaded = try JSONDecoder().decode([SessionSnapshot].self, from: Data(json.utf8))
        #expect(loaded.first?.lastEventAt == nil)
    }

    @Test func codexWithoutRolloutFileIsNotGuessed() throws {
        let inspector = FakeInspector([400: proc("codex")])
        #expect(SessionRecovery(inspector: inspector, claudeSessionsDirectory: try makeTempDirectory()).recover(snapshots: []).isEmpty)
        #expect(SessionRecovery.codexSessionId(fromPath: "/Users/me/.codex/sessions/x/notes.jsonl") == nil)
    }

    @Test func snapshotAndDiscoveryOfTheSameSessionAreOne() throws {
        let dir = try makeTempDirectory()
        try Data(#"{"pid":100,"sessionId":"a","cwd":"/Users/me/proj","status":"busy"}"#.utf8).write(to: dir.appendingPathComponent("100.json"))
        let inspector = FakeInspector([100: proc("claude")])
        let result = SessionRecovery(inspector: inspector, claudeSessionsDirectory: dir).recover(snapshots: [snapshot("a", pid: 100)])
        #expect(result.count == 1)
        #expect(result[0].terminalTitle == "saved title")
    }
}

@MainActor
struct AgentHubRestoreTests {
    @Test func eventsBeforeRestoreDoNotDuplicate() async throws {
        let dir = try makeTempDirectory()
        let source = FakeEventSource()
        let hub = AgentHub(
            source: source, locator: AgentLocator(inspector: FakeInspector([:])), titles: FakeTitles([:]),
            storage: .inDirectory(dir))
        hub.start()
        _ = source.send(envelope("UserPromptSubmit", session: "a", ts: 5))
        try await waitUntil { hub.sessions.count == 1 }
        hub.finishRestore([RecoveredSession(
            provider: .claude, sessionId: "a", cwd: "/Users/me/proj", agent: AgentIdentity(pid: 1, startedAt: "t"),
            orcaTerminal: nil, terminalTitle: nil, branch: nil, state: .unknown)])
        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].state == .working)  // the live event wins over the restored guess
    }

    @Test func restoredSessionKeepsItsRealLastActivity() throws {
        let hub = AgentHub(
            source: FakeEventSource(), locator: AgentLocator(inspector: FakeInspector([:])), titles: FakeTitles([:]),
            storage: .inDirectory(try makeTempDirectory()), now: { Date(timeIntervalSince1970: 5000) })
        hub.finishRestore([
            RecoveredSession(
                provider: .claude, sessionId: "old", cwd: "/p", agent: AgentIdentity(pid: 1, startedAt: "t"),
                orcaTerminal: nil, terminalTitle: nil, branch: nil, state: .idle, lastActivity: 100),
            RecoveredSession(
                provider: .claude, sessionId: "unknown", cwd: "/p", agent: AgentIdentity(pid: 2, startedAt: "t"),
                orcaTerminal: nil, terminalTitle: nil, branch: nil, state: .idle),
        ])
        let byId = Dictionary(uniqueKeysWithValues: hub.sessions.map { ($0.sessionId, $0) })
        #expect(byId["old"]?.lastEventAt == 100)
        #expect(byId["old"]?.stateSince == 100)
        #expect(byId["unknown"]?.lastEventAt == 5000)
    }

    @Test func restoredSessionShowsUnknownUntilNextEvent() async throws {
        let source = FakeEventSource()
        // Restore happens before the next hook event, as in real time
        let hub = AgentHub(
            source: source, locator: AgentLocator(inspector: FakeInspector([:])), titles: FakeTitles([:]),
            storage: .inDirectory(try makeTempDirectory()), now: { Date(timeIntervalSince1970: 5) })
        hub.start()
        hub.finishRestore([RecoveredSession(
            provider: .codex, sessionId: "x", cwd: "/p", agent: AgentIdentity(pid: 1, startedAt: "t"),
            orcaTerminal: "term_1", terminalTitle: "t", branch: nil, state: .unknown)])
        #expect(hub.sessions.first?.state == .unknown)
        _ = source.send(envelope("PreToolUse", session: "x", provider: .codex, tool: "shell", ts: 10))
        try await waitUntil { hub.sessions.first?.state == .working }
    }
}
