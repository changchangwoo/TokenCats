import Foundation

/// How often the room redraws. Lower rates save power; the cats walk the same, just in coarser steps.
enum AnimationQuality: String, CaseIterable, Codable, Sendable {
    case smooth, balanced, saver

    static let `default` = AnimationQuality.smooth

    var framesPerSecond: Double {
        switch self {
        case .smooth: return 12
        case .balanced: return 8
        case .saver: return 4
        }
    }
}

/// Battery saver: on battery or in Low Power Mode, the room drops to the saver rate and the closed notch stops
/// blinking, whatever quality the user picked.
enum PowerPolicy {
    struct Effective: Equatable, Sendable {
        let quality: AnimationQuality
        let blinks: Bool
    }

    static func effective(quality: AnimationQuality, saverEnabled: Bool, onBattery: Bool, lowPower: Bool) -> Effective {
        guard saverEnabled, onBattery || lowPower else { return Effective(quality: quality, blinks: true) }
        return Effective(quality: .saver, blinks: false)
    }
}

/// What the GitHub profile card shows besides the room. Everything is on by default: the numbers are the point
/// of sharing it, and each one can be switched off in Settings › GitHub 프로필.
struct ProfileCardOptions: Equatable, Sendable {
    var showsNumbers: Bool
    var showsYear: Bool

    static let `default` = ProfileCardOptions(showsNumbers: true, showsYear: true)

    /// What anyone visiting the profile sees besides the room; shown before the first upload.
    enum PublicItem: Equatable, Sendable { case numbers, year }

    var publicItems: [PublicItem] {
        [(showsNumbers, PublicItem.numbers), (showsYear, .year)].filter(\.0).map(\.1)
    }
}

/// When the profile card uploads by itself.
enum ProfileSyncMode: String, CaseIterable, Codable, Sendable {
    /// Once a day, and right after the room changes (cats, background, props).
    case changes
    /// Once a day only.
    case daily
    /// Only from "지금 갱신".
    case manual

    static let `default` = ProfileSyncMode.changes
}

/// Default values for every user preference, in one place. The app's `AppSettings` reads these so no view
/// repeats a literal; tests pin them because a wrong default ships to every new user.
enum PreferenceDefaults {
    static let language = "system"
    static let animationQuality = AnimationQuality.default.rawValue
    static let batterySaver = true
    static let closedNotchCats = true
    static let closedNotchBlink = true
    static let sessionAlerts = false
    static let profileShowsNumbers = ProfileCardOptions.default.showsNumbers
    static let profileShowsYear = ProfileCardOptions.default.showsYear
    static let profileSyncMode = ProfileSyncMode.default.rawValue
    static let roomTheme = RoomThemeCatalog.bundled.defaultID
}

/// Settings carried over from boring.notch's keys, applied once at launch.
enum PreferenceMigration {
    /// boring.notch's "show cool face while inactive" switch also governed the closed-notch cats. Off becomes
    /// "no closed-notch cats" unless the user has already chosen; nil means nothing to write.
    static func closedNotchCats(legacyShowFace: Bool?, current: Bool?) -> Bool? {
        guard legacyShowFace == false, current == nil else { return nil }
        return false
    }
}
