import AppKit
import LaunchAtLogin
import SwiftUI

/// The first-run window's state: which page shows, and the real actions behind each page. The connecting itself is
/// the same code Settings uses (AgentSetup, ProfileSync), so finishing here and connecting there end up alike.
@MainActor
final class OnboardingModel: ObservableObject {
    @Published private(set) var pages: [OnboardingStepKind] = []
    @Published private(set) var index = 0
    @Published private(set) var claude = AgentSetupState.notInstalled
    @Published private(set) var codex = AgentSetupState.notInstalled
    @Published private(set) var limitsOn = false
    @Published var launchAtLogin = true
    @Published private(set) var notice: LocalizedStringResource?
    @Published private(set) var githubBusy = false
    @Published private(set) var cardSVG: String?

    private let sync = ProfileSync.shared
    private var showingScanNote = false
    private var connectTask: Task<Void, Never>?
    private var cardTask: Task<Void, Never>?
    private let onClose: () -> Void
    private let onOpenCatRoom: () -> Void

    init(onClose: @escaping () -> Void, onOpenCatRoom: @escaping () -> Void) {
        self.onClose = onClose
        self.onOpenCatRoom = onOpenCatRoom
        refreshAgents()
        pages = OnboardingPlan.pages(claudePresent: claude != .notInstalled)
        launchAtLogin = OnboardingPlan.launchAtLoginDefault(firstLaunch: NotchCoordinator.shared.firstLaunch,
                                                            currentlyEnabled: LaunchAtLogin.isEnabled)
    }

    var page: OnboardingStepKind { pages[index] }
    var progress: OnboardingProgress { OnboardingProgress(step: index + 1, total: pages.count) }

    // MARK: Moving between pages

    func next() {
        leave(page, applying: true)
        advance()
    }

    /// "Skip" on a page: move on without applying that page's choice.
    func skip() {
        leave(page, applying: false)
        advance()
    }

    private func advance() {
        guard index < pages.count - 1 else { return }
        index += 1
        enter(page)
    }

    func back() {
        guard index > 0 else { return }
        notice = nil
        index -= 1
        enter(page)
    }

    /// "Skip" on the welcome page: no setup now; everything stays reachable from Settings.
    func skipAll() {
        NotchCoordinator.shared.firstLaunch = false
        close(openingRoom: false)
    }

    func finish() {
        close(openingRoom: true)
    }

    private func close(openingRoom: Bool) {
        connectTask?.cancel()
        cardTask?.cancel()
        onClose()
        if openingRoom { onOpenCatRoom() }
    }

    private func leave(_ page: OnboardingStepKind, applying: Bool) {
        notice = nil
        showingScanNote = false
        switch page {
        case .welcome:
            // Until this flips, the notch ignores hover and every launch replays the first-run window.
            NotchCoordinator.shared.firstLaunch = false
        case .loginItem where applying:
            if LaunchAtLogin.isEnabled != launchAtLogin { LaunchAtLogin.isEnabled = launchAtLogin }
        default:
            break
        }
    }

    private func enter(_ page: OnboardingStepKind) {
        switch page {
        case .agents: refreshAgents()
        case .limits: limitsOn = StatusLineIntegration.claude.isInstalled()
        case .github: loadCard()
        default: break
        }
    }

    // MARK: Agents and limits

    func refreshAgents() {
        claude = AgentSetup.state(of: .claude)
        codex = AgentSetup.state(of: .codex)
        limitsOn = StatusLineIntegration.claude.isInstalled()
    }

    func connect(_ provider: AgentProvider) {
        let name = provider == .codex ? "Codex" : "Claude Code"
        notice = AgentSetup.connectHook(AgentSetup.integration(for: provider), name: name).notice
        refreshAgents()
    }

    func turnOnLimits() {
        let outcome = AgentSetup.connectLimits()
        limitsOn = StatusLineIntegration.claude.isInstalled()
        if outcome.ok { next() } else { notice = outcome.notice }
    }

    // MARK: GitHub

    var githubPhase: OnboardingGitHubPhase {
        OnboardingGitHubPhase(connected: sync.state.isConnected, deviceCode: sync.deviceCode?.userCode,
                              repoReachable: !sync.repoIsMissing, needsAppInstall: sync.needsAppInstall,
                              readmeInstalled: sync.state.readmeInstalled)
    }

    var githubLogin: String { sync.state.owner ?? "" }

    /// The card exactly as it would be uploaded, redrawn when the shown items change.
    func loadCard() {
        cardTask?.cancel()
        // The first card waits for a full scan of past records; say so instead of a silent spinner.
        let firstScan = ProfileCard.needsFirstScan
        if firstScan && notice == nil {
            notice = "Reading past records for the first time… (about 30 seconds)"
            showingScanNote = true
        }
        cardTask = Task { [weak self] in
            let svg = try? await ProfileCard.render(owner: self?.sync.state.owner)
            guard !Task.isCancelled, let self else { return }
            self.cardSVG = svg
            if self.showingScanNote {
                self.notice = nil
                self.showingScanNote = false
            }
        }
    }

    /// The gh login when there is one, otherwise a code to enter on github.com.
    func connectGitHub() {
        runGitHub { [sync] in
            if GitHubCredentials.ghPath != nil {
                do {
                    try await sync.connect(.gh)
                    return
                } catch GitHubError.unauthorized where GitHubCredentials.deviceClientID != nil {
                    // gh is installed but logged out: fall through to the code.
                }
            }
            guard GitHubCredentials.deviceClientID != nil else { throw GitHubError.unauthorized }
            try await sync.connectWithDeviceCode()
        }
    }

    func cancelGitHubCode() {
        connectTask?.cancel()
    }

    func openDevicePage() {
        if let url = sync.deviceCode?.verificationURI { NSWorkspace.shared.open(url) }
    }

    func createProfileRepo() {
        guard let owner = sync.state.owner,
              let url = URL(string: "https://github.com/new?name=\(owner)&visibility=public") else { return }
        NSWorkspace.shared.open(url)
    }

    func installGitHubApp() {
        if let url = GitHubCredentials.appInstallURL { NSWorkspace.shared.open(url) }
    }

    func checkGitHubAgain() {
        guard !githubBusy else { return }
        runGitHub { [sync] in try await sync.recheckRepository() }
    }

    func addCardToReadme() {
        runGitHub { [sync] in try await sync.installReadme() }
    }

    func viewProfile() {
        if let owner = sync.state.owner, let url = URL(string: "https://github.com/\(owner)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func runGitHub(_ action: @escaping @MainActor () async throws -> Void) {
        connectTask?.cancel()
        notice = nil
        githubBusy = true
        connectTask = Task { [weak self] in
            defer { self?.githubBusy = false }
            do {
                try await action()
                self?.loadCard()
            } catch is CancellationError {
            } catch GitHubError.unauthorized {
                self?.notice = self?.sync.state.method == .device ? ProfileSyncProblem.reconnect.message
                    : "No GitHub login found. Run gh auth login in Terminal, then try again"
            } catch DeviceFlowError.denied {
                self?.notice = "Connection canceled on GitHub"
            } catch DeviceFlowError.expired {
                self?.notice = "The code expired. Try again"
            } catch {
                if !Task.isCancelled { self?.notice = ProfileSyncProblem(error).message }
            }
        }
    }

    // MARK: Finish

    var summary: [OnboardingSummaryItem] {
        var items: [OnboardingSummaryItem] = []
        if claude != .notInstalled { items.append(.init(label: "Claude Code connected", done: claude == .connected)) }
        if codex != .notInstalled { items.append(.init(label: "Codex connected", done: codex == .connected)) }
        if pages.contains(.limits) { items.append(.init(label: "Claude limits", done: limitsOn)) }
        items.append(.init(label: "GitHub card", done: sync.state.readmeInstalled))
        items.append(.init(label: "Launch at login", done: LaunchAtLogin.isEnabled))
        return items
    }

    var churu: Int { ChuruModel.shared.snapshot?.balance ?? 0 }
    var adoptionPrice: Int { StoreModel.shared.catalog?.catBox.price ?? 10_000_000 }
}

/// The first-run window: one page at a time, driven by OnboardingModel.
struct OnboardingFlowView: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var sync = ProfileSync.shared
    @AppStorage(AppSettings.Key.profileShowsNumbers) private var showsNumbers = AppSettings.Default.profileShowsNumbers
    @AppStorage(AppSettings.Key.profileShowsYear) private var showsYear = AppSettings.Default.profileShowsYear

    var body: some View {
        page
            .frame(width: onboardingWindowSize.width, height: onboardingWindowSize.height)
            .animation(.easeInOut(duration: 0.25), value: model.index)
            // Back from GitHub (repo created, app installed): look again without asking.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                if model.page == .github, case .needsAccess = model.githubPhase { model.checkGitHubAgain() }
                if model.page == .agents { model.refreshAgents() }
            }
            .onChange(of: showsNumbers) { model.loadCard() }
            .onChange(of: showsYear) { model.loadCard() }
    }

    @ViewBuilder private var page: some View {
        switch model.page {
        case .welcome:
            OnboardingWelcomeStep(progress: model.progress, onNext: model.next, onSkip: model.skipAll)
        case .agents:
            OnboardingAgentsStep(claude: model.claude, codex: model.codex, progress: model.progress,
                                 notice: model.notice, onConnect: model.connect, onCheckAgain: model.refreshAgents,
                                 onBack: model.back, onNext: model.next)
        case .limits:
            OnboardingLimitsStep(isOn: model.limitsOn, progress: model.progress, notice: model.notice,
                                 onTurnOn: model.turnOnLimits, onBack: model.back, onNext: model.next)
        case .github:
            OnboardingGitHubStep(
                phase: model.githubPhase, login: model.githubLogin, progress: model.progress,
                cardSVG: model.cardSVG, showsNumbers: $showsNumbers, showsYear: $showsYear,
                busy: model.githubBusy || sync.busy, notice: model.notice,
                actions: OnboardingGitHubActions(
                    connect: model.connectGitHub, openDevicePage: model.openDevicePage,
                    cancel: model.cancelGitHubCode, createRepo: model.createProfileRepo,
                    installApp: model.installGitHubApp, checkAgain: model.checkGitHubAgain,
                    addToReadme: model.addCardToReadme, viewProfile: model.viewProfile),
                onBack: model.back, onNext: model.next)
        case .loginItem:
            OnboardingLoginItemStep(isOn: $model.launchAtLogin, progress: model.progress,
                                    onBack: model.back, onSkip: model.skip, onNext: model.next)
        case .finish:
            OnboardingFinishStep(summary: model.summary, churu: model.churu, adoptionPrice: model.adoptionPrice,
                                 progress: model.progress, onBack: model.back, onFinish: model.finish)
        }
    }
}
