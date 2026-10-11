import Foundation
import Testing
@testable import TokenCatsCore

struct JSONSettingsFileTests {
    @Test func missingOrEmptyFileReadsAsEmptyObject() throws {
        let dir = try makeTempDirectory()
        let file = JSONSettingsFile(url: dir.appendingPathComponent("settings.json"))
        #expect(file.read() == nil)
        #expect(try JSONSettingsFile.object(from: file.read()).isEmpty)
        try Data().write(to: file.url)
        #expect(try JSONSettingsFile.object(from: file.read()).isEmpty)
    }

    @Test func brokenJSONIsReported() throws {
        #expect(throws: HookConfigError.invalidJSON) { try JSONSettingsFile.object(from: Data("{".utf8)) }
    }

    @Test func writeKeepsABackupAndPermissions() throws {
        let dir = try makeTempDirectory()
        let file = JSONSettingsFile(url: dir.appendingPathComponent("settings.json"))
        try Data("{\"a\":1}".utf8).write(to: file.url)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.url.path)
        try file.write(try JSONSettingsFile.serialize(["a": 1, "b": 2]))
        let backup = file.url.appendingPathExtension(JSONSettingsFile.backupExtension)
        #expect(try Data(contentsOf: backup) == Data("{\"a\":1}".utf8))
        #expect(try JSONSettingsFile.object(from: file.read())["b"] as? Int == 2)
        let mode = try FileManager.default.attributesOfItem(atPath: file.url.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    /// Hooks and the status line share ~/.claude/settings.json; each must leave the other's keys alone.
    @Test func hooksAndStatusLineShareOneFileWithoutClobbering() throws {
        let dir = try makeTempDirectory()
        let url = dir.appendingPathComponent("settings.json")
        try Data("{}".utf8).write(to: url)
        let hooks = HookIntegration(.claudeCode, hooksFile: url, scriptURL: dir.appendingPathComponent("tokencats-hook.py"))
        var status = StatusLineIntegration(settingsURL: url, scriptURL: dir.appendingPathComponent("tokencats-statusline.py"),
                                           originalURL: dir.appendingPathComponent("orig.json"))
        status.pythonIsUsable = { true }
        let script = dir.appendingPathComponent("bundled.py")
        try Data("#".utf8).write(to: script)
        try hooks.install(bundledScript: script)
        try status.install(bundledScript: script)
        #expect(hooks.isInstalled() && status.isInstalled())
        try hooks.uninstall()
        #expect(!hooks.isInstalled() && status.isInstalled())
        try status.uninstall()
        #expect(!hooks.isInstalled() && !status.isInstalled())
    }
}

struct AgentIntegrationTests {
    @Test func everyAgentNamesItsHooksFileAndEvents() {
        #expect(AgentIntegration.claudeCode.hooksFile.path.hasSuffix("/.claude/settings.json"))
        #expect(AgentIntegration.codex.hooksFile.path.hasSuffix("/.codex/hooks.json"))
        #expect(AgentIntegration.claudeCode.hookEvents.map(\.event).contains("SessionEnd"))
        #expect(!AgentIntegration.codex.hookEvents.map(\.event).contains("SessionEnd"))
        #expect(AgentIntegration.allCases.filter(\.supportsStatusLine) == [.claudeCode])
    }
}
