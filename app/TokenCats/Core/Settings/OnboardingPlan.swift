/// The first-run window's pages, in order.
enum OnboardingStepKind: Equatable, Sendable {
    case welcome, agents, limits, github, loginItem, finish
}

enum OnboardingPlan {
    /// The Claude limits page only shows when Claude Code is on this Mac: there is no status line to wrap otherwise.
    static func pages(claudePresent: Bool) -> [OnboardingStepKind] {
        [.welcome, .agents] + (claudePresent ? [.limits] : []) + [.github, .loginItem, .finish]
    }

    /// The launch-at-login switch starts on for a new install (closed means no churu); opened again from Settings,
    /// it shows what is set now, so walking through never changes it unasked.
    static func launchAtLoginDefault(firstLaunch: Bool, currentlyEnabled: Bool) -> Bool {
        firstLaunch || currentlyEnabled
    }
}

/// What the agents page says about one coding agent.
enum AgentSetupState: Equatable, Sendable {
    case connected, notConnected, notInstalled, needsPython

    /// `folderExists`: the agent's settings folder (`~/.claude`, `~/.codex`); without it there is nothing to hook.
    init(folderExists: Bool, hookInstalled: Bool, pythonUsable: Bool) {
        if hookInstalled { self = .connected }
        else if !folderExists { self = .notInstalled }
        else if !pythonUsable { self = .needsPython }
        else { self = .notConnected }
    }
}

/// Where the GitHub page is in connecting the profile card.
enum OnboardingGitHubPhase: Equatable, Sendable {
    case start
    /// Waiting for the user to enter this code at github.com/login/device.
    case code(String)
    /// Connected, but the profile repo is missing or the TokenCats App cannot see it yet.
    case needsAccess(appInstall: Bool)
    case ready
    case done

    init(connected: Bool, deviceCode: String?, repoReachable: Bool, needsAppInstall: Bool, readmeInstalled: Bool) {
        if let deviceCode { self = .code(deviceCode) }
        else if !connected { self = .start }
        else if readmeInstalled { self = .done }
        else if !repoReachable { self = .needsAccess(appInstall: needsAppInstall) }
        else { self = .ready }
    }
}
