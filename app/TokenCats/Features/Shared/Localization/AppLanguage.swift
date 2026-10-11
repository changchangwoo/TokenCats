import SwiftUI

/// The language the app shows, chosen in 설정 › 언어. One locale for every SwiftUI root; adding a language is a
/// catalog change only — the list of languages comes from the bundle.
@MainActor
final class AppLanguage: ObservableObject {
    static let shared = AppLanguage()
    static let systemSelection = LanguageSelection.system

    struct Language: Identifiable, Equatable {
        let code: String
        /// The language's own name for itself (한국어, English), independent of the current language.
        let name: String
        var id: String { code }
    }

    /// "system" or a language code; written straight to the preference so a relaunch starts in the same language.
    @Published var selection: String {
        didSet { UserDefaults.standard.set(selection, forKey: AppSettings.Key.language) }
    }

    private init() {
        selection = UserDefaults.standard.string(forKey: AppSettings.Key.language) ?? Self.systemSelection
    }

    /// Languages in the bundle, "Base" left out.
    var available: [Language] {
        Self.codes.map { code in
            Language(code: code, name: Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized ?? code)
        }
    }

    var locale: Locale {
        Locale(identifier: LanguageSelection.resolve(selection: selection, available: Self.codes,
                                                     preferred: Locale.preferredLanguages))
    }

    private static var codes: [String] { Bundle.main.localizations.filter { $0 != "Base" } }

    /// `resource` as plain text in the chosen language, for the few places outside SwiftUI (alerts, window
    /// titles, file names). Views use `Text(resource)` instead, which follows the language on its own.
    func string(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}
