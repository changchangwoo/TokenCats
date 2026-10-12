import Combine
import Sparkle
import SwiftUI

/// Updates through Sparkle: once a day it reads the signed appcast on github.com and, when a newer version is there,
/// asks before downloading and installing it. Settings › About has the switch and a manual check; the menu bar menu
/// has the check too. How the appcast is made and signed is in docs/setup/release.md.
///
/// TokenCats lives in the menu bar, so a scheduled check must not pop an alert over whatever the user is doing:
/// the found update is kept as `pendingVersion`, the home shows a line with an Update button and the menu bar menu
/// names the version, and only the user's click opens Sparkle's window (Sparkle calls this a gentle reminder).
@MainActor
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()

    @Published var automaticChecks: Bool {
        didSet { updater.automaticallyChecksForUpdates = automaticChecks }
    }
    /// False while a check or an install is already going on.
    @Published private(set) var canCheck = false
    /// A newer version a scheduled check found, not yet shown to the user.
    @Published private(set) var pendingVersion: String?
    /// The user said "Later" to the home's line; the menu bar menu still names the version.
    @Published private(set) var bannerDismissed = false

    private var controller: SPUStandardUpdaterController?
    private var updater: SPUUpdater!
    private var observers: Set<AnyCancellable> = []

    private override init() {
        automaticChecks = false
        super.init()
        #if DEBUG
        if let autopilot = UpdateAutopilot.fromEnvironment() {
            updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: autopilot, delegate: self)
        }
        #endif
        if updater == nil {
            let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self,
                                                          userDriverDelegate: self)
            self.controller = controller
            updater = controller.updater
        }
        automaticChecks = updater.automaticallyChecksForUpdates
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheck = $0 }
            .store(in: &observers)
    }

    /// Starts the scheduled checks; called once the app is up.
    func start() {
        if let controller {
            controller.startUpdater()
        } else {
            try? updater.start()
        }
        #if DEBUG
        if UpdateAutopilot.fromEnvironment() != nil { updater.checkForUpdates() }
        #endif
    }

    /// Opens Sparkle's window: a fresh check, or the update a scheduled check already found.
    func checkForUpdates() {
        updater.checkForUpdates()
    }

    func dismissBanner() {
        bannerDismissed = true
    }

    var lastCheck: Date? { updater.lastUpdateCheckDate }
}

extension AppUpdater: SPUUpdaterDelegate {
    /// Debug builds may point the updater at another feed (`NC_SPARKLE_FEED`), for testing the whole path against
    /// a local server; see docs/setup/release.md.
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["NC_SPARKLE_FEED"]
        #else
        return nil
        #endif
    }
}

#if DEBUG
/// With `NC_SPARKLE_AUTOPILOT=<log file>`, the update runs without anyone at the keyboard: every question Sparkle
/// would ask is answered with "go on", each step is appended to the log, and once the update is ready the app quits
/// so Sparkle installs it on the way out (no relaunch, so the test leaves nothing running).
final class UpdateAutopilot: NSObject, SPUUserDriver {
    private let log: URL

    static func fromEnvironment() -> UpdateAutopilot? {
        guard let path = ProcessInfo.processInfo.environment["NC_SPARKLE_AUTOPILOT"] else { return nil }
        return UpdateAutopilot(log: URL(fileURLWithPath: path))
    }

    private init(log: URL) {
        self.log = log
        super.init()
        try? "".write(to: log, atomically: true, encoding: .utf8)
    }

    private func note(_ line: String) {
        guard let handle = try? FileHandle(forWritingTo: log) else { return }
        handle.seekToEndOfFile()
        handle.write(Data((line + "\n").utf8))
        try? handle.close()
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        note("permission asked")
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { note("checking") }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                         reply: @escaping (SPUUserUpdateChoice) -> Void) {
        note("found \(appcastItem.displayVersionString) (\(appcastItem.versionString)) stage=\(state.stage.rawValue)")
        reply(.install)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        note("release notes \(downloadData.data.count) bytes")
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) { note("release notes failed: \(error)") }

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        note("not found: \(error)")
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        note("error: \(error)")
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) { note("downloading") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        note("expected \(expectedContentLength) bytes")
    }
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { note("extracting") }
    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        note("ready to install; quitting so it installs on quit")
        reply(.dismiss)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { NSApp.terminate(nil) }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool,
                              retryTerminatingApplication: @escaping () -> Void) {
        note("installing (terminated: \(applicationTerminated))")
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        note("installed (relaunched: \(relaunched))")
        acknowledgement()
    }

    func showUpdateInFocus() {}
    func dismissUpdateInstallation() { note("dismissed") }
}
#endif

extension AppUpdater: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Sparkle may show a scheduled update itself only when the app already has the user's attention.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                                          andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                               state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        let version = update.displayVersionString
        Task { @MainActor in
            self.pendingVersion = version
            self.bannerDismissed = false
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in self.pendingVersion = nil }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in self.pendingVersion = nil }
    }
}
