import Foundation

/// Where the app's screens live this launch: the notch window, or a panel under the menu bar icon.
enum ShellMode: String, Sendable {
    case notch
    case menuBar
}

/// The choice in Settings › General. `automatic` follows the hardware.
enum ShellPreference: String, CaseIterable, Sendable {
    case automatic
    case notch
    case menuBar

    static let `default` = ShellPreference.automatic

    /// An explicit choice always wins. `automatic` takes the notch only when a display has a camera notch: on any
    /// other display a drawn notch covers usable pixels, such as a browser's tab strip. `hasNotchDisplay` is nil when
    /// no display is connected yet (asleep at login); Automatic then keeps `lastMode`, or the notch without one.
    func resolve(hasNotchDisplay: Bool?, lastMode: ShellMode?) -> ShellMode {
        switch self {
        case .notch: return .notch
        case .menuBar: return .menuBar
        case .automatic:
            guard let hasNotchDisplay else { return lastMode ?? .notch }
            return hasNotchDisplay ? .notch : .menuBar
        }
    }

    /// The stored choice. Nothing stored (or an unknown value): a new install starts on `automatic`, while someone
    /// upgrading from the notch-only version keeps the notch they already had.
    static func stored(_ raw: String?, isFirstLaunch: Bool) -> ShellPreference {
        if let raw, let value = ShellPreference(rawValue: raw) { return value }
        return isFirstLaunch ? .default : .notch
    }
}
