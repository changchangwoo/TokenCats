import Foundation

/// Moves what "Notch Companion" left behind to the TokenCats names, once, before anything reads it. Each step is
/// idempotent and never overwrites data the new names already hold. Hook and status-line commands are rewritten
/// separately by `upgradeCommandIfNeeded`, which recognises the old markers.
enum IdentityMigration {
    /// Moves `NotchCompanion/` to the new support folder when only the old one exists. True when moved.
    @discardableResult
    static func moveSupportDirectory(home: URL, to destination: URL) -> Bool {
        let fileManager = FileManager.default
        let legacy = home.appendingPathComponent(LegacyIdentity.supportFolder, isDirectory: true)
        guard fileManager.fileExists(atPath: legacy.path), !fileManager.fileExists(atPath: destination.path) else {
            return false
        }
        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: legacy, to: destination)
        } catch {
            return false
        }
        // The old scripts are re-copied under the new names when their agent is connected.
        for name in [LegacyIdentity.hookMarker, LegacyIdentity.statusLineMarker] {
            try? fileManager.removeItem(at: destination.appendingPathComponent(name))
        }
        return true
    }

    /// The status line's untouched first backup, renamed so `StatusLineIntegration` can still recover from it.
    static func renameStatusLineFirstBackup(settingsURL: URL, to newURL: URL) {
        let legacy = settingsURL.appendingPathExtension(LegacyIdentity.statusLineFirstBackupExtension)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacy.path), !fileManager.fileExists(atPath: newURL.path) else { return }
        try? fileManager.moveItem(at: legacy, to: newURL)
    }

    /// Settings from the old preferences domain the new one does not have yet. Sparkle's `SU*` keys belong to
    /// boring.notch's updater, which the app no longer has.
    static func defaultsToCopy(legacy: [String: Any], existing: Set<String>) -> [String: Any] {
        legacy.filter { key, _ in !existing.contains(key) && !key.hasPrefix("SU") }
    }
}
