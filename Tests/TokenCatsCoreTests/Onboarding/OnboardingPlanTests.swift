import Testing
@testable import TokenCatsCore

/// Which first-run pages show, what each agent card says, and where the GitHub page is.
struct OnboardingPlanTests {
    @Test func allSixPagesWhenClaudeCodeIsThere() {
        #expect(OnboardingPlan.pages(claudePresent: true) == [.welcome, .agents, .limits, .github, .loginItem, .finish])
    }

    @Test func theLimitsPageNeedsClaudeCode() {
        #expect(OnboardingPlan.pages(claudePresent: false) == [.welcome, .agents, .github, .loginItem, .finish])
    }

    @Test func launchAtLoginStartsOnOnlyOnFirstRun() {
        #expect(OnboardingPlan.launchAtLoginDefault(firstLaunch: true, currentlyEnabled: false))
        #expect(!OnboardingPlan.launchAtLoginDefault(firstLaunch: false, currentlyEnabled: false))
        #expect(OnboardingPlan.launchAtLoginDefault(firstLaunch: false, currentlyEnabled: true))
    }

    @Test func agentStateReadsHookFolderAndPython() {
        #expect(AgentSetupState(folderExists: true, hookInstalled: true, pythonUsable: false) == .connected)
        #expect(AgentSetupState(folderExists: false, hookInstalled: false, pythonUsable: true) == .notInstalled)
        #expect(AgentSetupState(folderExists: true, hookInstalled: false, pythonUsable: false) == .needsPython)
        #expect(AgentSetupState(folderExists: true, hookInstalled: false, pythonUsable: true) == .notConnected)
    }

    @Test func githubPhaseFollowsTheConnection() {
        func phase(connected: Bool = false, code: String? = nil, reachable: Bool = true, appInstall: Bool = false,
                   readme: Bool = false) -> OnboardingGitHubPhase {
            OnboardingGitHubPhase(connected: connected, deviceCode: code, repoReachable: reachable,
                                  needsAppInstall: appInstall, readmeInstalled: readme)
        }
        #expect(phase() == .start)
        #expect(phase(code: "AB-12") == .code("AB-12"))
        #expect(phase(connected: true, code: "AB-12") == .code("AB-12"))
        #expect(phase(connected: true, reachable: false, appInstall: true) == .needsAccess(appInstall: true))
        #expect(phase(connected: true, reachable: false) == .needsAccess(appInstall: false))
        #expect(phase(connected: true) == .ready)
        #expect(phase(connected: true, readme: true) == .done)
    }
}
