import SwiftUI

/// Hangs the chosen language on a SwiftUI root: every `Text` below it re-renders when the language changes.
private struct LocalizedRoot: ViewModifier {
    @ObservedObject private var language = AppLanguage.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, language.locale)
            .environmentObject(language)
    }
}

extension View {
    func localized() -> some View { modifier(LocalizedRoot()) }
}
