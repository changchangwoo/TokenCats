import AppKit

/// Keeps the GitHub profile card current: uploads on the first connect, once a day, right after the cats or the background change,
/// and an hour after a failure. Checks every five minutes while the app runs; identical cards are not sent.
@MainActor
final class ProfileSync: ObservableObject {
    static let shared = ProfileSync()

    @Published private(set) var state: ProfileSyncState
    @Published private(set) var busy = false
    /// Shown while the user approves the device-flow code in the browser.
    @Published private(set) var deviceCode: DeviceCode?
    @Published private(set) var repoIsMissing = false
    @Published private(set) var repoIsPrivate = false
    /// Signed in with the GitHub App but it cannot see the profile repo yet: not installed there, or the repo does
    /// not exist. (GitHub answers 404 for both.)
    @Published private(set) var needsAppInstall = false

    private let file = DataFiles.live.profileSync
    private var timer: Timer?

    private init() {
        state = file.load() ?? ProfileSyncState()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in await ProfileSync.shared.syncIfDue() }
        }
        Task { await syncIfDue() }
    }

    func syncIfDue() async {
        let catsModified = (try? FileManager.default.attributesOfItem(
            atPath: DataFiles.live.cats.url.path))?[.modificationDate] as? Date
        guard ProfileSyncPolicy.shouldSync(state, now: Date(), catsModified: catsModified, themeID: Self.themeID,
                                           mode: AppSettings.profileSyncMode, calendar: .current) else { return }
        await sync()
    }

    /// The background the card is drawn with: the applied one if owned, otherwise the default.
    /// How the card's room looks: the background, a marker when the calendar is taken down, and the other props
    /// put up. A room with only the calendar keeps the value it had before props were sold.
    private static var themeID: String {
        let inventory = StoreModel.shared.inventory
        var id = RoomThemeSelection.selected(owned: inventory.ownedBackgrounds).id
        if !inventory.decor.shows(.calendar) { id += "|no-calendar" }
        let props = inventory.decor.shownProps.filter { !$0.isStarter }
        if !props.isEmpty { id += "|props:" + props.map(\.rawValue).joined(separator: ",") }
        return id
    }

    /// Builds the card and uploads it if it changed.
    func sync() async {
        guard !busy, let method = state.method, let owner = state.owner, let repo = state.repo else { return }
        busy = true
        defer { busy = false }
        state.lastAttemptAt = Date()
        do {
            let api = try await api(method)
            let svg = try await ProfileCard.render(owner: owner)
            if case let .uploaded(digest, _) = try await ProfilePublisher(api: api)
                .publish(svg: svg, owner: owner, repo: repo, lastDigest: state.lastDigest) {
                state.lastDigest = digest
            }
            state.lastUploadAt = Date()
            state.lastThemeID = Self.themeID
            state.lastError = nil
            markReachable()
        } catch GitHubError.unauthorized {
            state.lastError = ProfileSyncState.reconnectNeeded
        } catch GitHubError.notFound {
            markUnreachable(method: method)
            state.lastError = AppLanguage.shared.string(ProfileSyncProblem.repoMissing.message)
        } catch ProfileCardError.notReady {
            state.lastError = AppLanguage.shared.string("Still reading past records")
        } catch {
            state.lastError = AppLanguage.shared.string(ProfileSyncProblem(error).message)
        }
        file.save(state)
    }

    /// Connects with the given login, checks the profile repo, and uploads the first card.
    func connect(_ method: ProfileSyncState.Method) async throws {
        let api = try await api(method)
        let login = try await api.login()
        let (owner, repo) = Self.target(login: login)
        let found = try await api.repository(owner: owner, repo: repo)
        if found == nil { markUnreachable(method: method) } else { markReachable() }
        repoIsPrivate = found?.isPrivate ?? false
        var next = ProfileSyncState(method: method, owner: owner, repo: repo)
        if let found, let readme = try await api.readme(owner: owner, repo: repo, branch: found.defaultBranch) {
            next.readmeInstalled = ProfileReadme.hasBlock(readme.text)
        }
        state = next
        file.save(state)
        if found != nil { await sync() }
    }

    /// Device flow: shows the code, opens github.com/login/device, waits for approval, keeps the token in its private file.
    func connectWithDeviceCode() async throws {
        guard let clientID = GitHubCredentials.deviceClientID else { throw DeviceFlowError.disabled }
        let flow = DeviceFlow(clientID: clientID)
        let code = try await flow.start()
        deviceCode = code
        defer { deviceCode = nil }
        NSWorkspace.shared.open(code.verificationURI)
        guard GitHubCredentials.save(try await flow.poll(code)) else { throw CocoaError(.fileWriteUnknown) }
        deviceCode = nil
        try await connect(.device)
        // The browser is already open on GitHub: continue straight to letting the app reach the profile repo.
        if needsAppInstall, let install = GitHubCredentials.appInstallURL { NSWorkspace.shared.open(install) }
    }

    /// Looks for the profile repo again (after creating it or installing the app on it) and uploads when found.
    func recheckRepository() async throws {
        guard let method = state.method, let owner = state.owner, let repo = state.repo else { return }
        let api = try await api(method)
        guard let found = try await api.repository(owner: owner, repo: repo) else {
            markUnreachable(method: method)
            return
        }
        markReachable()
        repoIsPrivate = found.isPrivate
        if let readme = try await api.readme(owner: owner, repo: repo, branch: found.defaultBranch) {
            state.readmeInstalled = ProfileReadme.hasBlock(readme.text)
        }
        file.save(state)
        await sync()
    }

    private func markUnreachable(method: ProfileSyncState.Method) {
        needsAppInstall = method == .device
        repoIsMissing = true
    }

    private func markReachable() {
        needsAppInstall = false
        repoIsMissing = false
    }

    /// Adds the card between the README markers on the default branch (asked for in Settings first).
    func installReadme() async throws {
        guard let method = state.method, let owner = state.owner, let repo = state.repo else { return }
        let api = try await api(method)
        guard let found = try await api.repository(owner: owner, repo: repo) else {
            repoIsMissing = true
            throw GitHubError.notFound
        }
        let existing = try await api.readme(owner: owner, repo: repo, branch: found.defaultBranch)
        let text = ProfileReadme.upsert(existing?.text ?? "", owner: owner, repo: repo)
        if text != existing?.text {
            try await api.putReadme(owner: owner, repo: repo, branch: found.defaultBranch, text: text,
                                    sha: existing?.sha, message: "Add my cat room")
        }
        state.readmeInstalled = true
        file.save(state)
    }

    /// Forgets the connection; optionally takes the block back out of the README first.
    func disconnect(removingReadme: Bool) async {
        if removingReadme, let method = state.method, let owner = state.owner, let repo = state.repo,
           let api = try? await api(method), let found = try? await api.repository(owner: owner, repo: repo),
           let existing = try? await api.readme(owner: owner, repo: repo, branch: found.defaultBranch) {
            let text = ProfileReadme.remove(existing.text)
            if text != existing.text {
                try? await api.putReadme(owner: owner, repo: repo, branch: found.defaultBranch, text: text,
                                         sha: existing.sha, message: "Remove my cat room")
            }
        }
        if state.method == .device { GitHubCredentials.deleteSaved() }
        state = ProfileSyncState()
        repoIsMissing = false
        repoIsPrivate = false
        needsAppInstall = false
        file.save(state)
    }

    /// `<login>/<login>`, unless `defaults write … profileRepoOverride owner/repo` points elsewhere (for testing).
    static func target(login: String) -> (owner: String, repo: String) {
        if let override = AppSettings.profileRepoOverride {
            let parts = override.split(separator: "/").map(String.init)
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty { return (parts[0], parts[1]) }
        }
        return (login, login)
    }

    private func api(_ method: ProfileSyncState.Method) async throws -> GitHubAPI {
        guard let token = await GitHubCredentials.token(for: method) else { throw GitHubError.unauthorized }
        return GitHubAPI(token: token)
    }
}
