import Foundation

/// The companion's own data in the support directory: what a backup carries, what a restore or a reset replaces.
/// Restore and reset never delete: the current files move to `backups/before-…-<time>/` first.
enum Backup {
    static var files: [String] { DataFiles.userDataNames }

    /// Copies the data files that exist in `support` into a new folder `destination`.
    static func copy(from support: URL, to destination: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in files where manager.fileExists(atPath: support.appendingPathComponent(name).path) {
            try manager.copyItem(at: support.appendingPathComponent(name), to: destination.appendingPathComponent(name))
        }
    }

    /// Puts the backup's files in place, after moving the current ones aside. Returns the aside folder.
    @discardableResult
    static func restore(from backup: URL, into support: URL, now: Date = Date()) throws -> URL {
        let manager = FileManager.default
        let present = files.filter { manager.fileExists(atPath: backup.appendingPathComponent($0).path) }
        let aside = try moveAside(present, in: support, label: "before-restore", now: now)
        for name in present {
            try manager.copyItem(at: backup.appendingPathComponent(name), to: support.appendingPathComponent(name))
        }
        return aside
    }

    /// Moves every data file aside so the app starts fresh. Returns the aside folder.
    @discardableResult
    static func reset(_ support: URL, now: Date = Date()) throws -> URL {
        try moveAside(files, in: support, label: "before-reset", now: now)
    }

    private static func moveAside(_ names: [String], in support: URL, label: String, now: Date) throws -> URL {
        let manager = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let aside = support.appendingPathComponent("backups/\(label)-\(formatter.string(from: now))", isDirectory: true)
        try manager.createDirectory(at: aside, withIntermediateDirectories: true)
        for name in names where manager.fileExists(atPath: support.appendingPathComponent(name).path) {
            try manager.moveItem(at: support.appendingPathComponent(name), to: aside.appendingPathComponent(name))
        }
        return aside
    }
}
