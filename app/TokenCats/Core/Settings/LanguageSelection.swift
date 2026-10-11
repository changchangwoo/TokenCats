import Foundation

/// Which bundled language the `companionLanguage` preference means. Pure, so the choice can be tested without
/// the app bundle; `AppLanguage` feeds it the bundle's languages and the Mac's preferences.
enum LanguageSelection {
    static let system = "system"
    /// The source language: every key has it, so it never shows a missing translation.
    static let fallback = "en"

    /// `selection` when the bundle has it; for "system" the Mac's first preferred language the bundle has;
    /// otherwise `fallback`.
    static func resolve(selection: String, available: [String], preferred: [String]) -> String {
        if selection != system { return available.contains(selection) ? selection : fallback }
        return Bundle.preferredLocalizations(from: available, forPreferences: preferred).first ?? fallback
    }
}
