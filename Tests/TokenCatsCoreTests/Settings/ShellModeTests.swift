import Testing
@testable import TokenCatsCore

struct ShellPreferenceTests {
    /// Automatic puts the app in the notch only where there is a real notch to sit in.
    @Test func automaticFollowsTheHardware() {
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: true, lastMode: nil) == .notch)
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: false, lastMode: nil) == .menuBar)
    }

    @Test func anExplicitChoiceAlwaysWins() {
        #expect(ShellPreference.notch.resolve(hasNotchDisplay: false, lastMode: nil) == .notch)
        #expect(ShellPreference.menuBar.resolve(hasNotchDisplay: true, lastMode: nil) == .menuBar)
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

    /// At login the display can still be asleep: with no screen to look at, Automatic keeps what it chose last time.
    @Test func automaticWithNoDisplayYetKeepsTheLastMode() {
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: nil, lastMode: .notch) == .notch)
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: nil, lastMode: .menuBar) == .menuBar)
    }

    /// No display and no history (a first launch with the display asleep): the notch, the app's original home.
    @Test func automaticWithNoDisplayAndNoHistoryTakesTheNotch() {
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: nil, lastMode: nil) == .notch)
    }

    @Test func aDisplayOverridesTheLastMode() {
        #expect(ShellPreference.automatic.resolve(hasNotchDisplay: false, lastMode: .notch) == .menuBar)
        #expect(ShellPreference.menuBar.resolve(hasNotchDisplay: nil, lastMode: .notch) == .menuBar)
    }
}
