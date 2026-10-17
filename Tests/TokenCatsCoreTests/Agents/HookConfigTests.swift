import Foundation
import Testing
@testable import TokenCatsCore

private func json(_ data: Data) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func commands(_ root: [String: Any], _ event: String) -> [String] {
    let groups = (root["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
    return groups.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
}

struct HookConfigMergerTests {
    let command = "/usr/bin/python3 -I '/x/tokencats-hook.py' claude"
    let regs: [HookConfigMerger.Registration] = [
        .init(event: "Stop", matcher: nil, timeout: 5),
        .init(event: "PermissionRequest", matcher: "*", timeout: 130),
    ]
    let foreign = #"""
    {"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"warp-notify.sh"}]}],
     "SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"orca-hook.sh"}]}]}}
    """#

    @Test func installIntoEmptyConfig() throws {
        let root = try json(try HookConfigMerger.install(into: nil, command: command, registrations: regs))
        #expect(commands(root, "Stop") == [command])
        let permission = try #require(((root["hooks"] as? [String: Any])?["PermissionRequest"] as? [[String: Any]])?.first)
        #expect(permission["matcher"] as? String == "*")
        #expect((permission["hooks"] as? [[String: Any]])?.first?["timeout"] as? Int == 130)
    }

    @Test func installPreservesForeignHooksAndKeys() throws {
        let root = try json(try HookConfigMerger.install(into: Data(foreign.utf8), command: command, registrations: regs))
        #expect(root["model"] as? String == "opus")
        #expect(commands(root, "Stop") == ["warp-notify.sh", command])
        #expect(commands(root, "SessionStart") == ["orca-hook.sh"])
    }

    @Test func installTwiceIsIdempotent() throws {
        let once = try HookConfigMerger.install(into: Data(foreign.utf8), command: command, registrations: regs)
        let twice = try HookConfigMerger.install(into: once, command: command, registrations: regs)
        #expect(commands(try json(twice), "Stop") == ["warp-notify.sh", command])
    }

    @Test func uninstallRemovesOnlyOurEntries() throws {
        let installed = try HookConfigMerger.install(into: Data(foreign.utf8), command: command, registrations: regs)
        let root = try json(try HookConfigMerger.uninstall(from: installed))
        #expect(commands(root, "Stop") == ["warp-notify.sh"])
        #expect(commands(root, "SessionStart") == ["orca-hook.sh"])
        #expect((root["hooks"] as? [String: Any])?["PermissionRequest"] == nil)
        #expect(root["model"] as? String == "opus")
    }

    @Test func invalidJSONThrows() {
        #expect(throws: HookConfigError.invalidJSON) {
            try HookConfigMerger.install(into: Data("{oops".utf8), command: command, registrations: regs)
        }
    }
}

struct HookIntegrationTests {
    let dir: URL
    init() throws { dir = try makeTempDirectory() }

    func integration(config: URL) -> HookIntegration {
        var sut = HookIntegration(.claudeCode, hooksFile: config,
                                  scriptURL: dir.appendingPathComponent("support/tokencats-hook.py"))
        sut.pythonIsUsable = { true }
        return sut
    }

    @Test func installBacksUpCopiesScriptAndUninstalls() throws {
        let config = dir.appendingPathComponent("settings.json")
        let original = Data(#"{"model":"opus"}"#.utf8)
        try original.write(to: config)
        let sut = integration(config: config)
        #expect(!sut.isInstalled())
        try sut.install(bundledScript: hookScriptURL)
        #expect(sut.isInstalled())
        #expect(try Data(contentsOf: config.appendingPathExtension("tokencats.bak")) == original)
        #expect(FileManager.default.fileExists(atPath: sut.scriptURL.path))
        try sut.uninstall()
        #expect(!sut.isInstalled())
        #expect(try json(Data(contentsOf: config))["model"] as? String == "opus")
    }

    @Test func invalidJSONIsNeverOverwritten() throws {
        let config = dir.appendingPathComponent("settings.json")
        try Data("{oops".utf8).write(to: config)
        #expect(throws: HookIntegration.Failure.invalidConfig) {
            try integration(config: config).install(bundledScript: hookScriptURL)
        }
        #expect(try String(contentsOf: config, encoding: .utf8) == "{oops")
    }

    @Test func missingAgentDirectoryIsReported() {
        let config = dir.appendingPathComponent("no-such-agent/settings.json")
        #expect(throws: HookIntegration.Failure.agentNotInstalled) {
            try integration(config: config).install(bundledScript: hookScriptURL)
        }
    }

    @Test func symlinkedConfigStaysASymlink() throws {
        let real = dir.appendingPathComponent("dotfiles-settings.json")
        try Data("{}".utf8).write(to: real)
        let link = dir.appendingPathComponent("settings.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        try integration(config: link).install(bundledScript: hookScriptURL)
        let type = try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType
        #expect(type == .typeSymbolicLink)
        #expect(try String(contentsOf: real, encoding: .utf8).contains(HookConfigMerger.marker))
    }
}

struct HookScriptTests {
    let input = #"{"hook_event_name":"PermissionRequest","session_id":"abc","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"ls"}}"#

    @Test func scriptExitsQuietlyWhenSocketMissing() throws {
        let run = try runHookScript(socketPath: "/tmp/nc-does-not-exist.sock", provider: "claude", input: input)
        #expect(run.status == 0)
        #expect(run.stdout.isEmpty)
        #expect(run.elapsed < 3.0)  // the script's own timeout is 0.3 s; the rest is Python starting up
    }

    @Test func scriptExitsQuietlyWhenSocketIsStale() throws {
        let stale = try makeTempDirectory().appendingPathComponent("stale.sock")
        try Data().write(to: stale)
        let run = try runHookScript(socketPath: stale.path, provider: "claude", input: input)
        #expect(run.status == 0)
        #expect(run.stdout.isEmpty)
        #expect(run.elapsed < 3.0)  // the script's own timeout is 0.3 s; the rest is Python starting up
    }

    @Test func scriptIgnoresGarbageInput() throws {
        let stale = try makeTempDirectory().appendingPathComponent("stale.sock")
        try Data().write(to: stale)
        let run = try runHookScript(socketPath: stale.path, provider: "claude", input: "not json")
        #expect(run.status == 0)
        #expect(run.stdout.isEmpty)
    }
}

/// Runs a registered hook command the way the agents do: through `/bin/sh -c`, with the event on stdin.
private func runAsAgent(_ command: String, input: String = "{}") throws -> ScriptRun {
    signal(SIGPIPE, SIG_IGN)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    process.environment = ["HOME": NSHomeDirectory(), "PATH": "/usr/bin:/bin",
                           "TOKENCATS_SOCKET": "/tmp/nc-does-not-exist.sock"]
    let stdin = Pipe()
    let stdout = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    let start = Date()
    try process.run()
    stdin.fileHandleForWriting.write(Data(input.utf8))
    try stdin.fileHandleForWriting.close()
    let output = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ScriptRun(status: process.terminationStatus, stdout: String(decoding: output, as: UTF8.self),
                     elapsed: Date().timeIntervalSince(start))
}

/// A missing script must never stop the agent: python exits 2 for a missing file, and exit 2 makes Claude Code
/// block the tool call (PreToolUse), the prompt (UserPromptSubmit) or the stop (Stop).
struct HookCommandSafetyTests {
    let dir: URL
    init() throws { dir = try makeTempDirectory() }

    @Test func missingScriptExitsZero() throws {
        let sut = HookIntegration(.claudeCode, hooksFile: dir.appendingPathComponent("settings.json"),
                                  scriptURL: dir.appendingPathComponent("gone/tokencats-hook.py"))
        let run = try runAsAgent(sut.command)
        #expect(run.status == 0)
        #expect(run.stdout.isEmpty)
    }

    @Test func installedScriptStillRuns() throws {
        let script = dir.appendingPathComponent("support/tokencats-hook.py")
        try HookIntegration.copyScript(from: hookScriptURL, to: script)
        let sut = HookIntegration(.codex, hooksFile: dir.appendingPathComponent("hooks.json"), scriptURL: script)
        let run = try runAsAgent(sut.command, input: #"{"hook_event_name":"Stop"}"#)
        #expect(run.status == 0)
        #expect(run.stdout.isEmpty)
    }

    @Test func pathWithQuoteIsEscaped() throws {
        let script = dir.appendingPathComponent("it's here/tokencats-hook.py")
        try HookIntegration.copyScript(from: hookScriptURL, to: script)
        let sut = HookIntegration(.claudeCode, hooksFile: dir.appendingPathComponent("settings.json"), scriptURL: script)
        let run = try runAsAgent(sut.command)
        #expect(run.status == 0)
    }

    @Test func installRefusesWithoutPython() throws {
        let config = dir.appendingPathComponent("settings.json")
        try Data(#"{"model":"opus"}"#.utf8).write(to: config)
        var sut = HookIntegration(.claudeCode, hooksFile: config,
                                  scriptURL: dir.appendingPathComponent("support/tokencats-hook.py"))
        sut.pythonIsUsable = { false }
        #expect(throws: HookIntegration.Failure.pythonUnavailable) { try sut.install(bundledScript: hookScriptURL) }
        #expect(try String(contentsOf: config, encoding: .utf8) == #"{"model":"opus"}"#)
    }

    @Test func upgradeRewritesTheOldUnguardedCommandOnce() throws {
        let config = dir.appendingPathComponent("settings.json")
        let script = dir.appendingPathComponent("support/tokencats-hook.py")
        let old = "/usr/bin/python3 -I '\(script.path)' claude"
        try HookConfigMerger.install(into: Data(#"{"model":"opus"}"#.utf8), command: old,
                                     registrations: AgentIntegration.claudeCode.hookEvents).write(to: config)
        let sut = HookIntegration(.claudeCode, hooksFile: config, scriptURL: script)
        #expect(sut.upgradeCommandIfNeeded())
        let root = try json(Data(contentsOf: config))
        #expect(commands(root, "PreToolUse") == [sut.command])
        #expect(root["model"] as? String == "opus")
        #expect(!sut.upgradeCommandIfNeeded())
    }

    @Test func upgradeLeavesUnconnectedAgentsAlone() throws {
        let config = dir.appendingPathComponent("settings.json")
        try Data(#"{"model":"opus"}"#.utf8).write(to: config)
        let sut = HookIntegration(.claudeCode, hooksFile: config,
                                  scriptURL: dir.appendingPathComponent("support/tokencats-hook.py"))
        #expect(!sut.upgradeCommandIfNeeded())
        #expect(try String(contentsOf: config, encoding: .utf8) == #"{"model":"opus"}"#)
    }

    @Test func upgradeAddsClaudeFailureHookToExistingConnection() throws {
        let config = dir.appendingPathComponent("settings.json")
        let sut = HookIntegration(.claudeCode, hooksFile: config,
                                  scriptURL: dir.appendingPathComponent("support/tokencats-hook.py"))
        let previous = AgentIntegration.claudeCode.hookEvents.filter { $0.event != "StopFailure" }
        let old = try HookConfigMerger.install(into: Data(#"{"model":"opus"}"#.utf8),
                                               command: sut.command, registrations: previous)
        try old.write(to: config)

        #expect(sut.upgradeCommandIfNeeded())
        let root = try json(Data(contentsOf: config))
        #expect(commands(root, "StopFailure") == [sut.command])
        #expect(root["model"] as? String == "opus")
        #expect(!sut.upgradeCommandIfNeeded())
    }
}
