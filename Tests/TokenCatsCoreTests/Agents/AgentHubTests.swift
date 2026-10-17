import Foundation
import Testing
@testable import TokenCatsCore

final class FakeEventSource: AgentHookEventSource, @unchecked Sendable {
    private var handler: HookEnvelopeHandler?
    func start(onEvent: @escaping HookEnvelopeHandler) { handler = onEvent }
    func stop() { handler = nil }
    func send(_ envelope: HookEnvelope) -> Data? { handler?(envelope) }
}

final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        if clock.now > deadline {
            Issue.record("condition not met in time")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
struct AgentHubTests {
    @Test func permissionRequestIsObservedWithoutWaiting() async throws {
        let source = FakeEventSource()
        let hub = AgentHub(source: source, locator: AgentLocator(inspector: FakeInspector([:])), titles: FakeTitles([:]), storage: .inDirectory(try makeTempDirectory()))
        hub.start()
        let started = Date()
        #expect(source.send(envelope("PermissionRequest", tool: "Bash", ts: 1)) == nil)
        #expect(Date().timeIntervalSince(started) < 0.5)
        try await waitUntil { hub.sessions.first?.state == .needsApproval }
        _ = source.send(envelope("PostToolUse", tool: "Bash", ts: 2))
        try await waitUntil { hub.sessions.first?.state == .working }
    }
}

struct SocketIntegrationTests {
    @Test func scriptNeverWaitsForAReply() throws {
        let path = try makeTempDirectory().appendingPathComponent("c.sock").path
        let server = SocketServer(socketPath: path, clientReadTimeout: 0.5)
        let received = Box<HookEnvelope?>(nil)
        // A server that replies must not make the script print or wait.
        server.start { envelope in
            received.value = envelope
            return Data(#"{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}"#.utf8)
        }
        defer { server.stop() }
        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: path) && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }

        let input = #"{"hook_event_name":"PermissionRequest","session_id":"abc","cwd":"/tmp/proj","tool_name":"Bash","tool_input":{"command":"rm  -rf\n build"}}"#
        let run = try runHookScript(socketPath: path, provider: "claude", input: input, env: ["ORCA_TERMINAL_HANDLE": "term_1"])
        #expect(run.status == 0)
        #expect(run.stdout.isEmpty)
        #expect(run.elapsed < 3.0)  // fire-and-forget: the script's own timeout is 0.3 s; the rest is Python starting up
        #expect(received.value?.toolSummary == "rm -rf build")
        #expect(received.value?.orcaTerminal == "term_1")
    }

    @Test func scriptForwardsOnlyTheFailureKind() throws {
        let path = try makeTempDirectory().appendingPathComponent("failure.sock").path
        let server = SocketServer(socketPath: path, clientReadTimeout: 0.5)
        let received = Box<HookEnvelope?>(nil)
        server.start { envelope in received.value = envelope; return nil }
        defer { server.stop() }
        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: path) && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        let input = #"{"hook_event_name":"StopFailure","session_id":"s","cwd":"/tmp","error":"overloaded","error_details":"private details"}"#
        let run = try runHookScript(socketPath: path, provider: "claude", input: input)
        #expect(run.status == 0)
        #expect(received.value?.failureKind == "overloaded")
        #expect(received.value?.toolSummary == "")
    }
}

struct AgentLocatorTests {
    func detail(_ name: String, parent: Int32, command: String = "") -> ProcessDetail {
        ProcessDetail(tty: nil, startedAt: "s-\(name)", command: command, cwd: nil, parentPid: parent, name: name)
    }

    @Test func walksUpToTheAgentProcess() {
        let inspector = FakeInspector([
            300: detail("sh", parent: 200),
            200: detail("claude", parent: 100),
            100: detail("zsh", parent: 1),
        ])
        #expect(AgentLocator(inspector: inspector).agent(startingAt: 300, provider: .claude) == AgentIdentity(pid: 200, startedAt: "s-claude"))
    }

    @Test func recognizesNpmInstalledClaudeAndCodex() {
        let inspector = FakeInspector([
            300: detail("node", parent: 1, command: "node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"),
            400: detail("codex", parent: 1),
        ])
        let locator = AgentLocator(inspector: inspector)
        #expect(locator.agent(startingAt: 300, provider: .claude)?.pid == 300)
        #expect(locator.agent(startingAt: 400, provider: .codex)?.pid == 400)
        #expect(locator.agent(startingAt: 400, provider: .claude) == nil)
    }

    @Test func recognizesNativeClaudeRunningFromAVersionedBinary() {
        // Native installs exec ~/.local/share/claude/versions/<version>; the kernel name is the version.
        let inspector = FakeInspector([
            500: detail("2.1.287", parent: 1, command: "claude --dangerously-skip-permissions"),
            501: detail("node", parent: 1, command: "npm exec claude-code-templates@latest --mod x"),
            502: detail("zsh", parent: 1, command: "/bin/zsh -c echo claude"),
        ])
        let locator = AgentLocator(inspector: inspector)
        #expect(locator.agent(startingAt: 500, provider: .claude)?.pid == 500)
        #expect(locator.agent(startingAt: 501, provider: .claude) == nil)
        #expect(locator.agent(startingAt: 502, provider: .claude) == nil)
    }

    @Test func givesUpWithoutAgentAncestor() {
        let inspector = FakeInspector([300: detail("sh", parent: 1)])
        #expect(AgentLocator(inspector: inspector).agent(startingAt: 300, provider: .claude) == nil)
        #expect(AgentLocator(inspector: inspector).agent(startingAt: nil, provider: .claude) == nil)
    }

    @Test func livenessComparesStartTime() {
        let inspector = FakeInspector([200: detail("claude", parent: 1)])
        let locator = AgentLocator(inspector: inspector)
        #expect(locator.isAlive(AgentIdentity(pid: 200, startedAt: "s-claude")))
        #expect(!locator.isAlive(AgentIdentity(pid: 200, startedAt: "reused")))
        #expect(!locator.isAlive(AgentIdentity(pid: 201, startedAt: "s-claude")))
    }
}

@MainActor
struct AgentHubLivenessTests {
    @Test func sessionsOfDeadAgentsDisappearOnPrune() async throws {
        let inspector = FakeInspector([
            300: ProcessDetail(tty: nil, startedAt: "s", command: "", cwd: nil, parentPid: 1, name: "claude"),
        ])
        let source = FakeEventSource()
        let hub = AgentHub(source: source, locator: AgentLocator(inspector: inspector), storage: .inDirectory(try makeTempDirectory()))
        hub.start()
        _ = source.send(HookEnvelope(provider: .claude, sessionId: "s1", event: "UserPromptSubmit", cwd: "/p", tool: nil, toolSummary: nil, orcaTerminal: nil, ts: 1, hookPpid: 300))
        try await waitUntil { hub.sessions.first?.agent?.pid == 300 }
        inspector.details[300] = nil
        hub.pruneDeadSessions()
        #expect(hub.sessions.isEmpty)
    }
}

final class FakeTitles: TerminalTitleProvider, @unchecked Sendable {
    var titles: [String: String]
    private(set) var requests: [String] = []
    init(_ titles: [String: String]) { self.titles = titles }
    func info(for handle: String) -> TerminalInfo? {
        requests.append(handle)
        return titles[handle].map { TerminalInfo(title: $0, branch: nil) }
    }
}

struct OrcaTitleParsingTests {
    @Test func stripsStatusGlyphFromTitle() {
        let json = #"{"ok":true,"result":{"terminal":{"title":"◑ macOS notch app definition","handle":"term_1"}}}"#
        #expect(OrcaTerminalTitles.parseTitle(Data(json.utf8)) == "macOS notch app definition")
    }

    @Test func readsBranchWithoutRefsPrefix() {
        let json = #"{"ok":true,"result":{"terminal":{"title":"t","branch":"refs/heads/feat/notch-companion-mvp"}}}"#
        #expect(OrcaTerminalTitles.parseInfo(Data(json.utf8))?.branch == "feat/notch-companion-mvp")
    }

    @Test func keepsPlainTitlesAndRejectsBadOutput() {
        let plain = #"{"ok":true,"result":{"terminal":{"title":"quiz e2e"}}}"#
        #expect(OrcaTerminalTitles.parseTitle(Data(plain.utf8)) == "quiz e2e")
        #expect(OrcaTerminalTitles.parseTitle(Data(#"{"ok":false}"#.utf8)) == nil)
        #expect(OrcaTerminalTitles.parseTitle(Data("not json".utf8)) == nil)
        let blank = #"{"ok":true,"result":{"terminal":{"title":"◑ "}}}"#
        #expect(OrcaTerminalTitles.parseTitle(Data(blank.utf8)) == nil)
    }
}

@MainActor
struct AgentHubTitleTests {
    @Test func fetchesTerminalTitleOncePerSession() async throws {
        let source = FakeEventSource()
        let titles = FakeTitles(["term_1": "quiz e2e"])
        let hub = AgentHub(
            source: source,
            locator: AgentLocator(inspector: FakeInspector([:])), titles: titles, storage: .inDirectory(try makeTempDirectory()))
        hub.start()
        _ = source.send(envelope("UserPromptSubmit", ts: 1, terminal: "term_1"))
        try await waitUntil { hub.sessions.first?.terminalTitle == "quiz e2e" }
        _ = source.send(envelope("Stop", ts: 2, terminal: "term_1"))
        try await waitUntil { hub.sessions.first?.state == .turnDone }
        #expect(titles.requests == ["term_1"])
    }
}

@MainActor
private func makeHub(_ source: FakeEventSource, dir: URL, now: @escaping () -> Date = Date.init) -> AgentHub {
    AgentHub(
        source: source, locator: AgentLocator(inspector: FakeInspector([:])), titles: FakeTitles([:]),
        storage: .inDirectory(dir), now: now)
}

@MainActor
struct AgentHubResultTests {
    @Test func endedSessionKeepsUnseenResultUntilJumpSucceeds() async throws {
        let dir = try makeTempDirectory()
        let source = FakeEventSource()
        let hub = makeHub(source, dir: dir)
        hub.start()
        hub.finishRestore()
        _ = source.send(envelope("UserPromptSubmit", session: "a", ts: 1, terminal: "term_a"))
        _ = source.send(envelope("Stop", session: "a", ts: 2, terminal: "term_a"))
        _ = source.send(envelope("SessionEnd", session: "a", ts: 3))
        try await waitUntil { hub.sessions.isEmpty && hub.results.count == 1 }
        hub.finishJump("claude:a", succeeded: false)
        #expect(hub.results[0].seen == false)
        hub.finishJump("claude:a", succeeded: true)
        #expect(hub.results[0].seen == true)
        #expect(JSONFile<RecentResults>(url: dir.appendingPathComponent("results.json")).load()?.items.first?.seen == true)
    }

    @Test func newPromptMarksPreviousResultSeenAndFailureIsError() async throws {
        let source = FakeEventSource()
        let hub = makeHub(source, dir: try makeTempDirectory())
        hub.start()
        hub.finishRestore()
        _ = source.send(envelope("Stop", session: "a", ts: 1))
        try await waitUntil { hub.sessions.first?.unseenDone == true }
        _ = source.send(envelope("UserPromptSubmit", session: "a", ts: 2))
        try await waitUntil { hub.results.first?.seen == true && hub.sessions.first?.unseenDone == false }
        _ = source.send(envelope("StopFailure", session: "a", ts: 3))
        try await waitUntil { hub.results.first?.outcome == .error }
    }

    @Test func failedToolMidTurnIsNotAResult() async throws {
        let source = FakeEventSource()
        let hub = makeHub(source, dir: try makeTempDirectory())
        hub.start()
        hub.finishRestore()
        _ = source.send(envelope("UserPromptSubmit", session: "a", ts: 1))
        _ = source.send(envelope("PostToolUseFailure", session: "a", tool: "Bash", ts: 2))
        try await waitUntil { hub.sessions.first?.state == .error }
        #expect(hub.results.isEmpty)
        #expect(hub.sessions.first?.unseenDone == false)
    }
}

@MainActor
struct AgentHubServiceStatusTests {
    @Test func codexOfficialStatusRefreshesWithoutARequestFailure() async throws {
        let hub = AgentHub(source: FakeEventSource(), locator: AgentLocator(inspector: FakeInspector([:])),
                           titles: FakeTitles([:]), storage: .inDirectory(try makeTempDirectory()),
                           openAIStatusCheck: { .incident("Codex in ChatGPT Desktop") })
        hub.refreshOpenAIStatusIfNeeded()
        try await waitUntil { hub.openAIStatus == .incident("Codex in ChatGPT Desktop") }
        #expect(hub.serviceNotice == nil)
        #expect(hub.openAIIncidentNotice == .incident("Codex in ChatGPT Desktop"))
        hub.dismissOpenAIIncidentNotice()
        #expect(hub.openAIIncidentNotice == nil)
    }

    @Test func homeCheckPublishesOfficialStatusWithoutAClaudeFailure() async throws {
        let calls = Box(0)
        let hub = AgentHub(source: FakeEventSource(), locator: AgentLocator(inspector: FakeInspector([:])),
                           titles: FakeTitles([:]), storage: .inDirectory(try makeTempDirectory()),
                           statusCheck: { calls.value += 1; return .operational })
        hub.refreshClaudeStatusIfNeeded()
        try await waitUntil { hub.serviceStatus == .operational }
        hub.refreshClaudeStatusIfNeeded()
        #expect(calls.value == 1)
        #expect(hub.serviceNotice == nil)
    }

    @Test func checksClaudeServiceOnceForApiFailureAndPublishesResult() async throws {
        let source = FakeEventSource()
        let calls = Box(0)
        let hub = AgentHub(source: source, locator: AgentLocator(inspector: FakeInspector([:])),
                           titles: FakeTitles([:]), storage: .inDirectory(try makeTempDirectory()),
                           statusCheck: {
                               calls.value += 1
                               return .incident("Claude Code")
                           })
        hub.start()
        var failed = envelope("StopFailure", ts: 1)
        failed.failureKind = "server_error"
        _ = source.send(failed)
        try await waitUntil { hub.serviceNotice?.status == .incident("Claude Code") }
        #expect(hub.serviceNotice?.failureKind == "server_error")
        #expect(hub.claudeRequestFailed)
        _ = source.send(failed)
        try await Task.sleep(for: .milliseconds(50))
        #expect(calls.value == 1)
        _ = source.send(envelope("Stop", ts: 2))
        try await waitUntil { !hub.claudeRequestFailed }
        #expect(hub.serviceNotice == nil)
    }

    @Test func ignoresLocalFailuresAndCodex() async throws {
        let source = FakeEventSource()
        let calls = Box(0)
        let hub = AgentHub(source: source, locator: AgentLocator(inspector: FakeInspector([:])),
                           titles: FakeTitles([:]), storage: .inDirectory(try makeTempDirectory()),
                           statusCheck: { calls.value += 1; return .operational })
        hub.start()
        var rateLimit = envelope("StopFailure", ts: 1)
        rateLimit.failureKind = "rate_limit"
        _ = source.send(rateLimit)
        _ = source.send(envelope("PostToolUseFailure", ts: 2))
        var codexFailure = envelope("StopFailure", provider: .codex, ts: 3)
        codexFailure.failureKind = "server_error"
        _ = source.send(codexFailure)
        try await Task.sleep(for: .milliseconds(100))
        #expect(calls.value == 0)
        #expect(hub.serviceNotice == nil)
    }
}

@MainActor
struct AgentHubStorageTests {
    /// Files from the farm era stay on disk untouched; the hub neither reads nor deletes them.
    @Test func ignoresFarmEraFiles() async throws {
        let dir = try makeTempDirectory()
        let stale = dir.appendingPathComponent("animals.json")
        let bytes = Data("{\"claude:a\":{\"species\":\"cow\",\"variant\":2}}".utf8)
        try bytes.write(to: stale)
        let source = FakeEventSource()
        let hub = makeHub(source, dir: dir)
        hub.start()
        hub.finishRestore()
        _ = source.send(envelope("UserPromptSubmit", session: "a", ts: 1))
        try await waitUntil { hub.sessions.count == 1 }
        #expect(try Data(contentsOf: stale) == bytes)
        #expect(!Mirror(reflecting: hub).children.contains { $0.label == "animalBook" })
    }

    /// With the app closed the hook still reads its whole input, so an agent sending a large payload (over the
    /// 64 KB pipe buffer) never gets a broken pipe.
    @Test func hookDrainsLargeInputWhenTheAppIsNotRunning() throws {
        signal(SIGPIPE, SIG_IGN)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-I", hookScriptURL.path, "claude"]
        process.environment = ["HOME": NSHomeDirectory(), "PATH": "/usr/bin:/bin",
                               "TOKENCATS_SOCKET": "/tmp/tokencats-no-such-\(UUID().uuidString).sock"]
        let stdin = Pipe()
        process.standardInput = stdin
        try process.run()
        let payload = #"{"hook_event_name":"PostToolUse","tool_response":""# + String(repeating: "x", count: 300_000) + #""}"#
        try stdin.fileHandleForWriting.write(contentsOf: Data(payload.utf8))
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
}
