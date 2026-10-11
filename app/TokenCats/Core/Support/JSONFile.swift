import Foundation

/// One Codable value in one JSON file. A file that cannot be decoded is moved aside, never overwritten silently.
struct JSONFile<Value: Codable> {
    let url: URL

    func load(now: Date = Date()) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            let name = url.deletingPathExtension().lastPathComponent
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("\(name).corrupt-\(Int(now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            NSLog("[TokenCats] \(url.lastPathComponent) unreadable, moved to \(backup.lastPathComponent)")
            return nil
        }
    }

    /// Writes atomically. Returns false (and logs) when the file could not be written.
    @discardableResult
    func save(_ value: Value) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
            return true
        } catch {
            NSLog("[TokenCats] failed to save \(url.lastPathComponent): \(error)")
            return false
        }
    }
}
