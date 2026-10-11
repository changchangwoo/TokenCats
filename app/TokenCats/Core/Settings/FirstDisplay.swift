import Foundation

/// Which display the notch starts on before the user picks one in Settings.
enum FirstDisplay {
    struct Candidate: Equatable, Sendable {
        let uuid: String
        let isBuiltIn: Bool
        let isMain: Bool
    }

    /// The built-in display, where a MacBook's notch is, even when the menu bar lives on an external monitor;
    /// otherwise the main display, otherwise any.
    static func pick(_ displays: [Candidate]) -> String? {
        (displays.first(where: \.isBuiltIn) ?? displays.first(where: \.isMain) ?? displays.first)?.uuid
    }
}
