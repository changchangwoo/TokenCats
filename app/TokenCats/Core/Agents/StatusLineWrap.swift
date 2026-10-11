import Foundation

/// Wraps Claude Code's `statusLine` with ours, keeping every other key, and restores it exactly.
enum StatusLineMerger {
    static let marker = "tokencats-statusline.py"
    /// Ours under the current and the pre-TokenCats name.
    static let markers = [marker, LegacyIdentity.statusLineMarker]

    struct Wrapped {
        let settings: Data
        /// The user's `statusLine` to keep; nil when there was none or ours was already in place.
        let original: [String: Any]?
        let alreadyWrapped: Bool
    }

    static func wrap(_ data: Data?, command: String) throws -> Wrapped {
        var root = try JSONSettingsFile.object(from: data)
        let current = root["statusLine"] as? [String: Any]
        let alreadyWrapped = isOurs(current)
        var line = current ?? ["type": "command"]
        line["command"] = command
        root["statusLine"] = line
        return Wrapped(settings: try JSONSettingsFile.serialize(root), original: alreadyWrapped ? nil : current,
                       alreadyWrapped: alreadyWrapped)
    }

    /// nil when the current `statusLine` is not ours (the user replaced it): leave the file alone.
    static func unwrap(_ data: Data?, original: [String: Any]?) throws -> Data? {
        var root = try JSONSettingsFile.object(from: data)
        guard isOurs(root["statusLine"] as? [String: Any]) else { return nil }
        if let original { root["statusLine"] = original } else { root.removeValue(forKey: "statusLine") }
        return try JSONSettingsFile.serialize(root)
    }

    static func isWrapped(_ line: [String: Any]) -> Bool { isOurs(line) }

    /// The command currently in `statusLine`, ours or not.
    static func command(in data: Data?) -> String? {
        ((try? JSONSettingsFile.object(from: data))?["statusLine"] as? [String: Any])?["command"] as? String
    }

    static func isWrapped(_ data: Data?) -> Bool {
        guard let root = try? JSONSettingsFile.object(from: data) else { return false }
        return isOurs(root["statusLine"] as? [String: Any])
    }

    private static func isOurs(_ line: [String: Any]?) -> Bool {
        (line?["command"] as? String).map { command in markers.contains { command.contains($0) } } == true
    }

}

/// Connects the wrapper in `~/.claude/settings.json`. Same rules as the hooks (through `JSONSettingsFile`): a
/// backup before each write, broken JSON left alone, the installed script refreshed when the app updates. The
/// user's original `statusLine` is only forgotten after it has been written back.
struct StatusLineIntegration {
    enum Failure: Error, Equatable {
        /// `/usr/bin/python3` would only show the Command Line Tools installer; wrapping would blank the status line.
        case pythonUnavailable
    }

    let settingsURL: URL
    let scriptURL: URL
    let originalURL: URL
    var pythonIsUsable: () -> Bool = StatusLineIntegration.commandLineToolsInstalled

    static var claude: StatusLineIntegration {
        StatusLineIntegration(
            settingsURL: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json"),
            scriptURL: AppPaths.statusLineScriptURL, originalURL: AppPaths.statusLineOriginalURL)
    }

    var command: String { "/usr/bin/python3 -I \(ShellQuote.quote(scriptURL.path))" }

    private var file: JSONSettingsFile { JSONSettingsFile(url: settingsURL) }

    /// The settings file exactly as it was before the first connect; written once, never overwritten.
    var firstBackupURL: URL { settingsURL.appendingPathExtension("tokencats-statusline.bak") }

    func isInstalled() -> Bool {
        StatusLineMerger.isWrapped(file.read())
    }

    func install(bundledScript: URL) throws {
        guard FileManager.default.fileExists(atPath: settingsURL.deletingLastPathComponent().path) else {
            throw HookIntegration.Failure.agentNotInstalled
        }
        guard pythonIsUsable() else { throw Failure.pythonUnavailable }
        let existing = file.read()
        let wrapped: StatusLineMerger.Wrapped
        do {
            wrapped = try StatusLineMerger.wrap(existing, command: command)
        } catch {
            throw HookIntegration.Failure.invalidConfig
        }
        try HookIntegration.copyScript(from: bundledScript, to: scriptURL)
        if !wrapped.alreadyWrapped {
            try saveOriginal(wrapped.original)
            if let existing, !FileManager.default.fileExists(atPath: firstBackupURL.path) {
                try existing.write(to: firstBackupURL, options: .atomic)
            }
        } else if !FileManager.default.fileExists(atPath: originalURL.path) {
            // Wrapped but the kept original is gone: recover it from the untouched first backup.
            try saveOriginal(Self.statusLine(in: try? Data(contentsOf: firstBackupURL)))
        }
        try file.write(wrapped.settings)
    }

    func uninstall() throws {
        // Unreadable settings: keep the original so a later disconnect can still restore it.
        guard let existing = file.read() else { return }
        let restored: Data?
        do {
            restored = try StatusLineMerger.unwrap(existing, original: savedOriginal())
        } catch {
            throw HookIntegration.Failure.invalidConfig
        }
        if let restored { try file.write(restored) }
        // Written back, or the user replaced the status line themselves: the kept copy is no longer needed.
        try? FileManager.default.removeItem(at: originalURL)
    }

    /// Points an already-wrapped status line at the current script (e.g. after the TokenCats rename); true when
    /// the file was written. Never wraps a status line the user has not connected.
    @discardableResult
    func upgradeCommandIfNeeded() -> Bool {
        let existing = file.read()
        guard isInstalled(), StatusLineMerger.command(in: existing) != command,
              let wrapped = try? StatusLineMerger.wrap(existing, command: command) else { return false }
        return (try? file.write(wrapped.settings)) != nil
    }

    /// Keeps the installed wrapper in sync with the app bundle after updates.
    static func refreshInstalledScript(from bundledScript: URL) {
        guard AgentIntegration.claudeCode.supportsStatusLine, claude.isInstalled() else { return }
        try? HookIntegration.copyScript(from: bundledScript, to: AppPaths.statusLineScriptURL)
    }

    /// `xcode-select -p` fails without Xcode or the Command Line Tools, and never shows the installer.
    static func commandLineToolsInstalled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 && FileManager.default.isExecutableFile(atPath: "/usr/bin/python3")
        } catch {
            return false
        }
    }

    private func saveOriginal(_ original: [String: Any]?) throws {
        let saved = try JSONSerialization.data(withJSONObject: ["statusLine": original.map { $0 as Any } ?? NSNull()],
                                               options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try saved.write(to: originalURL, options: .atomic)
    }

    private func savedOriginal() -> [String: Any]? {
        guard let data = try? Data(contentsOf: originalURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return root["statusLine"] as? [String: Any]
    }

    /// The `statusLine` in a settings file, unless it is already ours.
    private static func statusLine(in data: Data?) -> [String: Any]? {
        guard let data, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let line = root["statusLine"] as? [String: Any],
              !StatusLineMerger.isWrapped(line) else { return nil }
        return line
    }
}
