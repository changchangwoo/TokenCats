import Foundation

/// One of the user's agent settings files (`~/.claude/settings.json`, `~/.codex/hooks.json`): read through its
/// symlink, written back with the previous content kept in a `.bak` beside it and the file's permissions intact.
/// Both the hook and the status-line installers go through here, so they never clobber each other's keys.
struct JSONSettingsFile {
    let url: URL
    static let backupExtension = "tokencats.bak"

    /// The current bytes, or nil when the file does not exist.
    func read() -> Data? {
        try? Data(contentsOf: url.resolvingSymlinksInPath())
    }

    func write(_ data: Data) throws {
        let target = url.resolvingSymlinksInPath()
        let manager = FileManager.default
        if let existing = read() {
            try existing.write(to: url.appendingPathExtension(Self.backupExtension), options: .atomic)
        }
        // An atomic write replaces the file, which would reset its permissions.
        let permissions = (try? manager.attributesOfItem(atPath: target.path))?[.posixPermissions]
        try data.write(to: target, options: .atomic)
        if let permissions { try? manager.setAttributes([.posixPermissions: permissions], ofItemAtPath: target.path) }
    }

    /// A missing or empty file is an empty object; anything that is not a JSON object is `invalidJSON`.
    static func object(from data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data), let dict = object as? [String: Any] else {
            throw HookConfigError.invalidJSON
        }
        return dict
    }

    static func serialize(_ root: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}
