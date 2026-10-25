import Testing
@testable import TokenCatsCore

struct ShellPreferenceTests {
    /// Automatic puts the app in the notch only where there is a real notch to sit in.
    @Test func automaticFollowsTheHardware() {
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: true) == .notch)
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: false) == .menuBar)
    }

    @Test func anExplicitChoiceAlwaysWins() {
        #expect(ShellPreference.notch.resolve(hasNotchDisplay: false) == .notch)
        #expect(ShellPreference.menuBar.resolve(hasNotchDisplay: true) == .menuBar)
    }

    @Test func aNewInstallStartsOnAutomatic() {
        #expect(ShellPreference.stored(nil, isFirstLaunch: true) == .automatic)
    }

    /// Someone who used the notch-only version never chose; an update must not move their app.
    @Test func upgradingUserKeepsTheNotch() {
        #expect(ShellPreference.stored(nil, isFirstLaunch: false) == .notch)
    }

    @Test func aStoredChoiceIsReadBack() {
        #expect(ShellPreference.stored("menuBar", isFirstLaunch: false) == .menuBar)
        #expect(ShellPreference.stored("automatic", isFirstLaunch: false) == .automatic)
        #expect(ShellPreference.stored("notch", isFirstLaunch: true) == .notch)
    }

    @Test func anUnknownValueFallsBackLikeAMissingOne() {
        #expect(ShellPreference.stored("dock", isFirstLaunch: true) == .automatic)
        #expect(ShellPreference.stored("dock", isFirstLaunch: false) == .notch)
    }
}
