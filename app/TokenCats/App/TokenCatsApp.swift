import Combine
import Defaults
import SwiftUI
import UserNotifications

@main
struct TokenCatsApp: App {
    /// Declared first so it runs before the delegate and `@Default` read preferences or the data folder.
    private let migrated: Void = LegacyDataMigration.beforeLaunch()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Default(.menubarIcon) var showMenuBarIcon
    @Environment(\.openWindow) var openWindow
    @ObservedObject private var updater = AppUpdater.shared

    var body: some Scene {
        // Notch mode only: menu bar mode draws its own status item (MenuBarShellController), which opens the panel.
        // A template image (art-src/menubar, scripts/build-menubar-icon.swift): white on a dark menu bar,
        // black on a light one.
        MenuBarExtra(isInserted: ShellLaunch.mode == .notch ? $showMenuBarIcon : .constant(false)) {
            menu.localized()
        } label: {
            Image("MenuBarIcon").accessibilityLabel(Text(verbatim: "TokenCats"))
        }
    }

    @ViewBuilder private var menu: some View {
        Button("Settings") {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showWindow()
            }
        }
        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
        if let version = updater.pendingVersion {
            Button("Update to TokenCats \(version)…") { updater.checkForUpdates() }
        } else {
            Button("Check for Updates…") { updater.checkForUpdates() }
        }
        Divider()
        Button("Restart TokenCats") {
            Relaunch.now()
        }
        Button("Quit", role: .destructive) {
            NSApplication.shared.terminate(self)
        }
        .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    /// The notch or the menu bar panel, whichever this launch runs (`ShellLaunch`).
    private let shell: CompanionShell = ShellLaunch.makeShell()
    private var onboardingWindowController: NSWindowController?
    private var onboardingModel: OnboardingModel?
    private var serviceNoticeSubscription: AnyCancellable?
    private var openAIIncidentSubscription: AnyCancellable?
    private var lastNotifiedService: String?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AgentHub.shared.stop()
        serviceNoticeSubscription = nil
        openAIIncidentSubscription = nil
        NotificationCenter.default.removeObserver(self)
        shell.stop()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["NC_SNAPSHOT_DIR"] != nil {
            DebugSnapshots.runIfRequested()
            return
        }
        #endif
        AppSettings.migrateLegacy()
        AgentHub.shared.start()
        AgentHub.shared.restoreLive()
        serviceNoticeSubscription = AgentHub.shared.$serviceNotice
            .compactMap { $0 }
            .sink { [weak self] notice in
                guard let self else { return }
                guard case .incident(let service) = notice.status else {
                    if case .operational = notice.status { lastNotifiedService = nil }
                    return
                }
                guard lastNotifiedService != service else { return }
                lastNotifiedService = service
                Task { @MainActor in
                    let center = UNUserNotificationCenter.current()
                    guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
                    let content = UNMutableNotificationContent()
                    content.title = AppLanguage.shared.string("Claude service issue reported")
                    content.body = AppLanguage.shared.string("Your Claude Code request failed. Check the official status page.")
                    try? await center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                                                 content: content, trigger: nil))
                }
            }
        openAIIncidentSubscription = AgentHub.shared.$openAIIncidentNotice
            .compactMap { $0 }
            .sink { status in
                guard case .incident = status else { return }
                Task { @MainActor in
                    let center = UNUserNotificationCenter.current()
                    guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
                    let content = UNMutableNotificationContent()
                    content.title = AppLanguage.shared.string("OpenAI Codex service issue reported")
                    content.body = AppLanguage.shared.string("Codex Desktop is affected; CLI impact is unknown. Check OpenAI status.")
                    try? await center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                                                 content: content, trigger: nil))
                }
            }
        LegacyDataMigration.upgradeAgentCommands(
            hookScript: Bundle.main.url(forResource: "tokencats-hook", withExtension: "py"),
            statusLineScript: Bundle.main.url(forResource: "tokencats-statusline", withExtension: "py"))
        ProfileSync.shared.start()
        CatBondModel.shared.start()
        AppUpdater.shared.start()
        shell.start()

        NotificationCenter.default.addObserver(self, selector: #selector(showOnboardingWindow),
                                               name: .showOnboardingRequested, object: nil)

        if NotchCoordinator.shared.firstLaunch {
            shell.beginFirstRun { [weak self] in self?.showOnboardingWindow() }
        }
    }

    /// The first-run window; also opened again from Settings › General. Each opening starts a fresh flow from the
    /// welcome page, with every step reflecting what is already connected.
    @objc func showOnboardingWindow() {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: onboardingWindowSize),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = AppLanguage.shared.string("Get started with TokenCats")
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            let model = OnboardingModel(
                onClose: { [weak self] in
                    window.orderOut(nil)
                    window.close()
                    self?.onboardingWindowController = nil
                    self?.onboardingModel = nil
                    NSApp.deactivate()
                },
                onOpenCatRoom: { [weak self] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.shell.openCompanion() }
                })
            onboardingModel = model
            window.contentView = NSHostingView(rootView: OnboardingFlowView(model: model).localized())
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")

            onboardingWindowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}

extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let firstRunSceneFinished = Notification.Name("firstRunSceneFinished")
    /// Settings › General › "Show first-run setup again".
    static let showOnboardingRequested = Notification.Name("showOnboardingRequested")
}

extension CGRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
