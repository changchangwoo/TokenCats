import Foundation

/// Names the app used before it became TokenCats ("Notch Companion"). Only `IdentityMigration` and the code
/// that must still recognise entries written under these names (hooks, status line, README block) read them.
enum LegacyIdentity {
    static let bundleID = "com.changwoo.notchcompanion"
    static let supportFolder = "Library/Application Support/NotchCompanion"
    static let hookMarker = "notch-companion-hook.py"
    static let statusLineMarker = "notch-companion-statusline.py"
    static let statusLineFirstBackupExtension = "notch-companion-statusline.bak"
    static let readmeStart = "<!-- notch-companion:start -->"
    static let readmeEnd = "<!-- notch-companion:end -->"
}
