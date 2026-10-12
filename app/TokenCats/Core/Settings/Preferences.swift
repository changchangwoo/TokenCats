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

/// Battery saver: on battery or in Low Power Mode, the room drops to the saver rate and small decorative
/// animations (the loading dots) hold still, whatever quality the user picked.
enum PowerPolicy {
    struct Effective: Equatable, Sendable {
        let quality: AnimationQuality
        let smallAnimations: Bool
    }

    static func effective(quality: AnimationQuality, saverEnabled: Bool, onBattery: Bool, lowPower: Bool) -> Effective {
        guard saverEnabled, onBattery || lowPower else { return Effective(quality: quality, smallAnimations: true) }
        return Effective(quality: .saver, smallAnimations: false)
    }
}

/// What the GitHub profile card shows besides the room. The numbers and the year are on by default: they are the
/// point of sharing it. The cats' bond levels are off until the user switches them on. Each one can be changed in
/// Settings › GitHub 프로필.
struct ProfileCardOptions: Equatable, Sendable {
    var showsNumbers: Bool
    var showsYear: Bool
    var showsLevels: Bool

    init(showsNumbers: Bool, showsYear: Bool, showsLevels: Bool = false) {
        self.showsNumbers = showsNumbers
        self.showsYear = showsYear
        self.showsLevels = showsLevels
    }

    static let `default` = ProfileCardOptions(showsNumbers: true, showsYear: true, showsLevels: false)

    /// What anyone visiting the profile sees besides the room; shown before the first upload.
    enum PublicItem: Equatable, Sendable { case numbers, year, levels }

    var publicItems: [PublicItem] {
        [(showsNumbers, PublicItem.numbers), (showsYear, .year), (showsLevels, .levels)].filter(\.0).map(\.1)
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
    static let batterySaver = false
    /// The missions section on Home starts open; the chevron folds it and the choice sticks.
    static let missionsExpanded = true
    static let closedNotchCats = true
    static let profileShowsNumbers = ProfileCardOptions.default.showsNumbers
    static let profileShowsYear = ProfileCardOptions.default.showsYear
    static let profileShowsLevels = ProfileCardOptions.default.showsLevels
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
