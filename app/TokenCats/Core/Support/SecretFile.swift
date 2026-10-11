import Foundation

/// A small JSON file only its owner can read (0600), for a secret that must survive app updates. The keychain
/// cannot hold it for an ad-hoc signed app: every build has a new signature and loses access to items the last
/// one saved. Same footing as the GitHub CLI's own token file.
struct SecretFile<Value: Codable> {
    let url: URL

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// Written to a private temporary file first, so the secret is never readable by others even for a moment.
    @discardableResult
    func save(_ value: Value) -> Bool {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(value)
            let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString)")
            guard manager.createFile(atPath: temporary.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
                return false
            }
            _ = try manager.replaceItemAt(url, withItemAt: temporary)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            return false
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
