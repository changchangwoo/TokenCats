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
        didSet { controller.updater.automaticallyChecksForUpdates = automaticChecks }
    }
    /// False while a check or an install is already going on.
    @Published private(set) var canCheck = false
    /// A newer version a scheduled check found, not yet shown to the user.
    @Published private(set) var pendingVersion: String?
    /// The user said "Later" to the home's line; the menu bar menu still names the version.
    @Published private(set) var bannerDismissed = false

    private var controller: SPUStandardUpdaterController!
    private var observers: Set<AnyCancellable> = []

    private override init() {
        automaticChecks = false
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        automaticChecks = controller.updater.automaticallyChecksForUpdates
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheck = $0 }
            .store(in: &observers)
    }

    /// Starts the scheduled checks; called once the app is up.
    func start() {
        controller.startUpdater()
    }

    /// Opens Sparkle's window: a fresh check, or the update a scheduled check already found.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func dismissBanner() {
        bannerDismissed = true
    }

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }
}

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
