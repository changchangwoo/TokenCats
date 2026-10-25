import AppKit

/// One way of showing the app's screens. Exactly one runs per launch, picked by `ShellLaunch`; everything the
/// shells share (agents, sync, updates, onboarding) stays in `AppDelegate`. A new shell is a `ShellMode` case plus a
/// type conforming here.
@MainActor
protocol CompanionShell: AnyObject {
    /// Creates the shell's windows or status item and starts listening for what moves them. Called once at launch.
    func start()
    /// Tears down before the app quits.
    func stop()
    /// Shows the cat room, as onboarding's last step asks.
    func openCompanion()
    /// The very first launch: whatever this shell plays first, then `showOnboarding` exactly once.
    func beginFirstRun(showOnboarding: @escaping @MainActor @Sendable () -> Void)
}

/// The shell this launch runs in, decided once: changing the preference in Settings relaunches the app.
@MainActor
enum ShellLaunch {
    /// Nil while no display is connected (asleep at login): nothing to tell yet.
    static var hasNotchDisplay: Bool? {
        let screens = NSScreen.screens
        return screens.isEmpty ? nil : screens.contains { $0.safeAreaInsets.top > 0 }
    }

    static let mode: ShellMode = {
        let defaults = UserDefaults.standard
        let preference = ShellPreference.stored(defaults.string(forKey: AppSettings.Key.shellPreference),
                                                isFirstLaunch: NotchCoordinator.shared.firstLaunch)
        let lastMode = defaults.string(forKey: AppSettings.Key.shellLastMode).flatMap(ShellMode.init(rawValue:))
        let mode = preference.resolve(hasNotchDisplay: hasNotchDisplay, lastMode: lastMode)
        // Written back so a new user who finishes onboarding (firstLaunch turns false) keeps Automatic next launch,
        // and so a launch with no display yet can follow this one.
        defaults.set(preference.rawValue, forKey: AppSettings.Key.shellPreference)
        defaults.set(mode.rawValue, forKey: AppSettings.Key.shellLastMode)
        return mode
    }()

    static func makeShell() -> CompanionShell {
        switch mode {
        case .notch: return NotchShellController()
        case .menuBar: return MenuBarShellController()
        }
    }
}
