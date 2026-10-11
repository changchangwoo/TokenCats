import Foundation
import Testing
@testable import TokenCatsCore

private func root(_ data: Data?) throws -> [String: Any] {
    let bytes = try #require(data)
    return try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
}

private let command = "/usr/bin/python3 -I '/x/tokencats-statusline.py'"
private let userLine = #"{"model":"opus","statusLine":{"type":"command","command":"/Users/me/context-bar.sh","padding":1}}"#

struct StatusLineMergerTests {
    @Test func wrapKeepsOtherKeysAndReturnsTheOriginal() throws {
        let wrapped = try StatusLineMerger.wrap(Data(userLine.utf8), command: command)
        let settings = try root(wrapped.settings)
        #expect(settings["model"] as? String == "opus")
        let line = try #require(settings["statusLine"] as? [String: Any])
        #expect(line["command"] as? String == command)
        #expect(line["padding"] as? Int == 1)
        #expect(wrapped.original?["command"] as? String == "/Users/me/context-bar.sh")
        #expect(!wrapped.alreadyWrapped)
        #expect(StatusLineMerger.isWrapped(wrapped.settings))
    }

    @Test func wrapCreatesAStatusLineWhenThereWasNone() throws {
        let wrapped = try StatusLineMerger.wrap(Data(#"{"model":"opus"}"#.utf8), command: command)
        let line = try #require(try root(wrapped.settings)["statusLine"] as? [String: Any])
        #expect(line["type"] as? String == "command")
        #expect(wrapped.original == nil)
    }

    @Test func connectTwiceKeepsTheFirstOriginal() throws {
        let first = try StatusLineMerger.wrap(Data(userLine.utf8), command: command)
        let second = try StatusLineMerger.wrap(first.settings, command: command)
        #expect(second.alreadyWrapped)
        #expect(second.original == nil)
    }

    @Test func unwrapRestoresTheOriginalExactly() throws {
        let wrapped = try StatusLineMerger.wrap(Data(userLine.utf8), command: command)
        let restored = try #require(try StatusLineMerger.unwrap(wrapped.settings, original: wrapped.original))
        let line = try #require(try root(restored)["statusLine"] as? [String: Any])
        #expect(line["command"] as? String == "/Users/me/context-bar.sh")
        #expect(line["padding"] as? Int == 1)
        #expect(!StatusLineMerger.isWrapped(restored))
    }

    @Test func unwrapRemovesStatusLineThatDidNotExist() throws {
        let wrapped = try StatusLineMerger.wrap(Data(#"{"model":"opus"}"#.utf8), command: command)
        let restored = try #require(try StatusLineMerger.unwrap(wrapped.settings, original: nil))
        #expect(try root(restored)["statusLine"] == nil)
        #expect(try root(restored)["model"] as? String == "opus")
    }

    @Test func unwrapLeavesAStatusLineTheUserReplaced() throws {
        #expect(try StatusLineMerger.unwrap(Data(userLine.utf8), original: nil) == nil)
    }

    @Test func brokenSettingsAreRefused() {
        #expect(throws: HookConfigError.invalidJSON) {
            try StatusLineMerger.wrap(Data("{not json".utf8), command: command)
        }
    }
}

struct StatusLineIntegrationTests {
    private func integration(in folder: URL) -> StatusLineIntegration {
        StatusLineIntegration(settingsURL: folder.appendingPathComponent("settings.json"),
                              scriptURL: folder.appendingPathComponent("support/tokencats-statusline.py"),
                              originalURL: folder.appendingPathComponent("support/statusline-original.json"),
                              pythonIsUsable: { true })
    }

    @Test func installThenUninstallRoundTrips() throws {
        let folder = try makeTempDirectory()
        let settings = folder.appendingPathComponent("settings.json")
        try Data(userLine.utf8).write(to: settings)
        let script = folder.appendingPathComponent("bundled.py")
        try Data("print('x')".utf8).write(to: script)
        let line = integration(in: folder)

        try line.install(bundledScript: script)
        #expect(line.isInstalled())
        #expect(FileManager.default.fileExists(atPath: line.scriptURL.path))
        let saved = try root(try Data(contentsOf: line.originalURL))
        #expect((saved["statusLine"] as? [String: Any])?["command"] as? String == "/Users/me/context-bar.sh")

        try line.install(bundledScript: script)
        try line.uninstall()
        #expect(!line.isInstalled())
        let restored = try #require(try root(try Data(contentsOf: settings))["statusLine"] as? [String: Any])
        #expect(restored["command"] as? String == "/Users/me/context-bar.sh")
        #expect(!FileManager.default.fileExists(atPath: line.originalURL.path))
    }

    @Test func failedUninstallKeepsTheSavedOriginal() throws {
        let folder = try makeTempDirectory()
        let settings = folder.appendingPathComponent("settings.json")
        try Data(userLine.utf8).write(to: settings)
        let script = folder.appendingPathComponent("bundled.py")
        try Data("print('x')".utf8).write(to: script)
        let line = integration(in: folder)
        try line.install(bundledScript: script)

        try Data("{broken".utf8).write(to: settings)
        #expect(throws: HookIntegration.Failure.invalidConfig) { try line.uninstall() }
        #expect(FileManager.default.fileExists(atPath: line.originalURL.path))

        try FileManager.default.removeItem(at: settings)
        try line.uninstall()
        #expect(FileManager.default.fileExists(atPath: line.originalURL.path))
    }

    @Test func reconnectRecoversAMissingOriginalFromTheFirstBackup() throws {
        let folder = try makeTempDirectory()
        let settings = folder.appendingPathComponent("settings.json")
        try Data(userLine.utf8).write(to: settings)
        let script = folder.appendingPathComponent("bundled.py")
        try Data("print('x')".utf8).write(to: script)
        let line = integration(in: folder)
        try line.install(bundledScript: script)
        try FileManager.default.removeItem(at: line.originalURL)

        try line.install(bundledScript: script)
        let saved = try root(try Data(contentsOf: line.originalURL))
        #expect((saved["statusLine"] as? [String: Any])?["command"] as? String == "/Users/me/context-bar.sh")
    }

    @Test func firstConnectKeepsTheUntouchedFileAndItsPermissions() throws {
        let folder = try makeTempDirectory()
        let settings = folder.appendingPathComponent("settings.json")
        try Data(userLine.utf8).write(to: settings)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.path)
        let script = folder.appendingPathComponent("bundled.py")
        try Data("print('x')".utf8).write(to: script)
        let line = integration(in: folder)

        try line.install(bundledScript: script)
        try line.uninstall()
        try line.install(bundledScript: script)
        #expect(try Data(contentsOf: line.firstBackupURL) == Data(userLine.utf8))
        let mode = try FileManager.default.attributesOfItem(atPath: settings.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test func installRefusesWithoutAUsablePython() throws {
        let folder = try makeTempDirectory()
        let settings = folder.appendingPathComponent("settings.json")
        try Data(userLine.utf8).write(to: settings)
        var line = integration(in: folder)
        line.pythonIsUsable = { false }
        #expect(throws: StatusLineIntegration.Failure.pythonUnavailable) {
            try line.install(bundledScript: folder.appendingPathComponent("x.py"))
        }
        #expect(try Data(contentsOf: settings) == Data(userLine.utf8))
    }

    @Test func installWithoutClaudeFolderFails() throws {
        let folder = try makeTempDirectory().appendingPathComponent("missing")
        #expect(throws: HookIntegration.Failure.agentNotInstalled) {
            try integration(in: folder).install(bundledScript: folder.appendingPathComponent("x.py"))
        }
    }

    /// A home folder with an apostrophe (e.g. /Users/o'brien) must still give `sh -c` one intact path.
    @Test func commandQuotesApostrophesInThePath() throws {
        let path = "/Users/o'brien/Library/Application Support/TokenCats/tokencats-statusline.py"
        let integration = StatusLineIntegration(settingsURL: URL(fileURLWithPath: "/tmp/settings.json"),
                                                scriptURL: URL(fileURLWithPath: path),
                                                originalURL: URL(fileURLWithPath: "/tmp/original.json"))
        let echo = Process()
        echo.executableURL = URL(fileURLWithPath: "/bin/sh")
        echo.arguments = ["-c", integration.command.replacingOccurrences(of: "/usr/bin/python3 -I ", with: "printf %s ")]
        let out = Pipe()
        echo.standardOutput = out
        try echo.run()
        echo.waitUntilExit()
        #expect(String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self) == path)
    }
}
