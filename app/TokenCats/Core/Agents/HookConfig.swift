import Foundation

enum HookConfigError: Error, Equatable {
    case invalidJSON
}

/// Adds/removes our command in a Claude `settings.json` or Codex `hooks.json` without touching other entries.
/// Shape: {"hooks": {"<Event>": [{"matcher"?: String, "hooks": [{"type": "command", "command": String, "timeout"?: Int}]}]}}
enum HookConfigMerger {
    static let marker = "tokencats-hook.py"
    /// Ours under the current and the pre-TokenCats name; both are replaced on install and removed on uninstall.
    static let markers = [marker, LegacyIdentity.hookMarker]

    struct Registration: Sendable {
        let event: String
        let matcher: String?
        let timeout: Int?
    }

    static func install(into data: Data?, command: String, registrations: [Registration]) throws -> Data {
        var root = try JSONSettingsFile.object(from: data)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for registration in registrations {
            var groups = (hooks[registration.event] as? [[String: Any]] ?? []).compactMap(strip)
            var entry: [String: Any] = ["type": "command", "command": command]
            if let timeout = registration.timeout { entry["timeout"] = timeout }
            var group: [String: Any] = ["hooks": [entry]]
            if let matcher = registration.matcher { group["matcher"] = matcher }
            groups.append(group)
            hooks[registration.event] = groups
        }
        root["hooks"] = hooks
        return try JSONSettingsFile.serialize(root)
    }

    static func uninstall(from data: Data?) throws -> Data {
        var root = try JSONSettingsFile.object(from: data)
        guard var hooks = root["hooks"] as? [String: Any] else { return try JSONSettingsFile.serialize(root) }
        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            let kept = groups.compactMap(strip)
            hooks[event] = kept.isEmpty && !groups.isEmpty ? nil : kept
        }
        root["hooks"] = hooks
        return try JSONSettingsFile.serialize(root)
    }

    /// Every command of ours in the file, across events.
    static func commands(in root: [String: Any]) -> [String] {
        guard let hooks = root["hooks"] as? [String: Any] else { return [] }
        return hooks.values.compactMap { $0 as? [[String: Any]] }.joined()
            .flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
            .filter(isOurs)
    }

    static func isOurs(_ command: String) -> Bool {
        markers.contains { command.contains($0) }
    }

    /// Removes our entries from one matcher group; nil when nothing else remains in it.
    private static func strip(_ group: [String: Any]) -> [String: Any]? {
        guard let entries = group["hooks"] as? [[String: Any]] else { return group }
        let kept = entries.filter { !isOurs(($0["command"] as? String) ?? "") }
        if kept.count == entries.count { return group }
        if kept.isEmpty { return nil }
        var copy = group
        copy["hooks"] = kept
        return copy
    }
}

/// Installs the hook script for one agent: a backup before each write, broken JSON left alone, the installed
/// script refreshed when the app updates.
struct HookIntegration {
    enum Failure: Error, Equatable {
        case agentNotInstalled
        case invalidConfig
        /// `/usr/bin/python3` would only show the Command Line Tools installer on every hook.
        case pythonUnavailable
    }

    let agent: AgentIntegration
    let file: JSONSettingsFile
    let scriptURL: URL
    var pythonIsUsable: () -> Bool = StatusLineIntegration.commandLineToolsInstalled

    init(_ agent: AgentIntegration, hooksFile: URL? = nil, scriptURL: URL = AppPaths.hookScriptURL) {
        self.agent = agent
        self.file = JSONSettingsFile(url: hooksFile ?? agent.hooksFile)
        self.scriptURL = scriptURL
    }

    static var claude: HookIntegration { HookIntegration(.claudeCode) }
    static var codex: HookIntegration { HookIntegration(.codex) }

    /// Always exits 0. Without the guard a deleted script makes python exit 2, which Claude Code reads as "block":
    /// every tool call, prompt and stop would fail until the user found the entry. The else branch drains stdin so
    /// the agent never writes into a closed pipe.
    var command: String {
        let script = ShellQuote.quote(scriptURL.path)
        return "if [ -f \(script) ]; then /usr/bin/python3 -I \(script) \(agent.provider.rawValue); "
            + "else cat >/dev/null 2>&1; fi; exit 0"
    }

    func isInstalled() -> Bool {
        guard let data = file.read() else { return false }
        let text = String(decoding: data, as: UTF8.self)
        return HookConfigMerger.markers.contains { text.contains($0) }
    }

    func install(bundledScript: URL) throws {
        guard FileManager.default.fileExists(atPath: file.url.deletingLastPathComponent().path) else {
            throw Failure.agentNotInstalled
        }
        guard pythonIsUsable() else { throw Failure.pythonUnavailable }
        let merged: Data
        do {
            merged = try HookConfigMerger.install(into: file.read(), command: command, registrations: agent.hookEvents)
        } catch {
            throw Failure.invalidConfig
        }
        try Self.copyScript(from: bundledScript, to: scriptURL)
        try file.write(merged)
    }

    func uninstall() throws {
        guard let existing = file.read() else { return }
        let cleaned: Data
        do {
            cleaned = try HookConfigMerger.uninstall(from: existing)
        } catch {
            throw Failure.invalidConfig
        }
        try file.write(cleaned)
    }

    /// Rewrites an older form of our command (e.g. the unguarded one) in place; true when the file was written.
    /// Leaves agents the user never connected untouched.
    @discardableResult
    func upgradeCommandIfNeeded() -> Bool {
        guard let data = file.read(), isInstalled(),
              let root = try? JSONSettingsFile.object(from: data),
              HookConfigMerger.commands(in: root).contains(where: { $0 != command }),
              let merged = try? HookConfigMerger.install(into: data, command: command, registrations: agent.hookEvents)
        else { return false }
        return (try? file.write(merged)) != nil
    }

    /// Keeps the installed script in sync with the app bundle after updates.
    static func refreshInstalledScript(from bundledScript: URL) {
        guard AgentIntegration.allCases.contains(where: { HookIntegration($0).isInstalled() }) else { return }
        try? copyScript(from: bundledScript, to: AppPaths.hookScriptURL)
    }

    static func copyScript(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.copyItem(at: source, to: destination)
    }
}
