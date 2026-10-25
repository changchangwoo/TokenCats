import SwiftUI

/// The app's user preferences in UserDefaults: every key and every default, in one place. Views bind with
/// `@AppStorage(AppSettings.Key.x) private var x = AppSettings.Default.x`; models read the static accessors.
enum AppSettings {
    enum Key {
        static let language = "companionLanguage"
        /// When the user last dismissed the "some data could not be read" banner (seconds since 1970).
        static let unreadDataNoticedAt = "unreadDataNoticedAt"
        static let animationQuality = "companionAnimationQuality"
        static let batterySaver = "companionBatterySaver"
        static let closedNotchCats = "companionClosedNotchCats"
        static let missionsExpanded = "companionMissionsExpanded"
        static let profileShowsNumbers = "profileShowsTokenNumbers"
        static let profileShowsYear = "profileShowsYear"
        static let profileShowsLevels = "profileShowsLevels"
        static let profileSyncMode = "profileSyncMode"
        /// The applied room background.
        static let roomTheme = RoomThemeSelection.key
        /// The notch tab to reopen on.
        static let lastNotchTab = "companionLastNotchTab"
        /// `ShellPreference` raw value: Automatic, Notch or Menu bar. Read once per launch (`ShellLaunch`).
        static let shellPreference = "shellPreference"
        /// Every store price is 0 (Debug default; `defaults write … storeFreeForTesting -bool NO` to turn off).
        static let storeFreeForTesting = "storeFreeForTesting"
        /// Overrides for the GitHub connection, set with `defaults write` while testing.
        static let githubAppClientID = "githubAppClientID"
        static let profileRepoOverride = "profileRepoOverride"
        /// Set once the Notch Companion preferences have been copied over (`LegacyDataMigration`).
        static let identityMigrated = "identityMigrated"
    }

    typealias Default = PreferenceDefaults

    private static var defaults: UserDefaults { .standard }

    private static func bool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }

    static var animationQuality: AnimationQuality {
        defaults.string(forKey: Key.animationQuality).flatMap(AnimationQuality.init(rawValue:)) ?? .default
    }
    static var batterySaver: Bool { bool(Key.batterySaver, default: Default.batterySaver) }
    static var closedNotchCats: Bool { bool(Key.closedNotchCats, default: Default.closedNotchCats) }
    static var missionsExpanded: Bool { bool(Key.missionsExpanded, default: Default.missionsExpanded) }
    static var roomThemeID: String { defaults.string(forKey: Key.roomTheme) ?? Default.roomTheme }

    static var profileCardOptions: ProfileCardOptions {
        ProfileCardOptions(showsNumbers: bool(Key.profileShowsNumbers, default: Default.profileShowsNumbers),
                           showsYear: bool(Key.profileShowsYear, default: Default.profileShowsYear),
                           showsLevels: bool(Key.profileShowsLevels, default: Default.profileShowsLevels))
    }

    static var profileSyncMode: ProfileSyncMode {
        defaults.string(forKey: Key.profileSyncMode).flatMap(ProfileSyncMode.init(rawValue:)) ?? .default
    }

    /// Unset means the Debug default; Release builds charge real churu unless the user opts in.
    static var storeFreeForTesting: Bool {
        if let value = defaults.object(forKey: Key.storeFreeForTesting) as? Bool { return value }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var githubAppClientID: String? { defaults.string(forKey: Key.githubAppClientID) }
    static var profileRepoOverride: String? { defaults.string(forKey: Key.profileRepoOverride) }

    /// Carries boring.notch-era choices over once. Safe to call every launch.
    static func migrateLegacy() {
        let legacyFaceKey = "showNotHumanFace"
        guard defaults.object(forKey: legacyFaceKey) != nil else { return }
        if let cats = PreferenceMigration.closedNotchCats(legacyShowFace: defaults.object(forKey: legacyFaceKey) as? Bool,
                                                         current: defaults.object(forKey: Key.closedNotchCats) as? Bool) {
            defaults.set(cats, forKey: Key.closedNotchCats)
        }
        defaults.removeObject(forKey: legacyFaceKey)
    }

    /// The quality and blinking in force now, with battery saver applied. A Mac without a battery is never
    /// "on battery".
    @MainActor static var power: PowerPolicy.Effective {
        let battery = BatteryStatusViewModel.shared
        let onBattery = battery.maxCapacity > 0 && !battery.isPluggedIn
        let lowPower = battery.isInLowPowerMode || ProcessInfo.processInfo.isLowPowerModeEnabled
        return PowerPolicy.effective(quality: animationQuality, saverEnabled: batterySaver,
                                     onBattery: onBattery, lowPower: lowPower)
    }
}
