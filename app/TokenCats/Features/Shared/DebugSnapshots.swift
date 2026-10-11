#if DEBUG
import SwiftUI

/// Debug builds only: with `NC_SNAPSHOT_DIR` set, writes the store's three pages and My Cats as PNGs at the open
/// notch's size and quits, so layouts can be checked without screen recording.
@MainActor
enum DebugSnapshots {
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["NC_SNAPSHOT_DIR"] else { return }
        // With NC_SNAPSHOT_CARDS=1, writes the profile card once per background instead of the screens.
        if ProcessInfo.processInfo.environment["NC_SNAPSHOT_CARDS"] != nil {
            Task { @MainActor in
                for background in RoomThemeCatalog.bundled.backgrounds {
                    let svg = try? await ProfileCard.render(owner: "changchangwoo", theme: background.theme)
                    try? svg?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("card-\(background.id).svg"),
                                    atomically: true, encoding: .utf8)
                }
                NSApp.terminate(nil)
            }
            return
        }
        // With NC_SNAPSHOT_ONBOARDING=1, writes the first-run pages in each designed state instead
        // (NC_SNAPSHOT_CARD_SVG: a profile card to show on the GitHub page).
        if ProcessInfo.processInfo.environment["NC_SNAPSHOT_ONBOARDING"] != nil {
            Task { @MainActor in
                var card: NSImage?
                if let path = ProcessInfo.processInfo.environment["NC_SNAPSHOT_CARD_SVG"],
                   let svg = try? String(contentsOfFile: path, encoding: .utf8) {
                    card = await ProfileCardPage.snapshot(svg)
                }
                let login = "changchangwoo"
                let pages: [(String, AnyView)] = [
                    ("1-welcome", AnyView(OnboardingWelcomeStep())),
                    ("2-agents", AnyView(OnboardingAgentsStep(claude: .connected, codex: .notConnected))),
                    ("2-agents-problems", AnyView(OnboardingAgentsStep(claude: .needsPython, codex: .notInstalled))),
                    ("3-limits", AnyView(OnboardingLimitsStep())),
                    ("4a-github-start", AnyView(OnboardingGitHubStep(phase: .start, login: login, card: card))),
                    ("4b-github-code", AnyView(OnboardingGitHubStep(phase: .code("A1B2-C3D4"), login: login, card: card))),
                    ("4c-github-access", AnyView(OnboardingGitHubStep(phase: .needsAccess(repoCreated: true), login: login,
                                                                      card: card))),
                    ("4d-github-ready", AnyView(OnboardingGitHubStep(phase: .ready, login: login, card: card))),
                    ("4e-github-done", AnyView(OnboardingGitHubStep(phase: .done, login: login, card: card))),
                    ("5-login-item", AnyView(OnboardingLoginItemStep())),
                    ("6-finish", AnyView(OnboardingFinishStep(summary: [
                        OnboardingSummaryItem(label: "Claude Code connected", done: true),
                        OnboardingSummaryItem(label: "Codex connected", done: false),
                        OnboardingSummaryItem(label: "Claude limits", done: true),
                        OnboardingSummaryItem(label: "GitHub card", done: true),
                        OnboardingSummaryItem(label: "Launch at login", done: true),
                    ], churu: 0, adoptionPrice: 10_000_000))),
                ]
                let theme = StoreModel.shared.theme(id: AppSettings.roomThemeID)
                let coat = StoreModel.shared.household.residents.first?.coat ?? "black"
                let storyboard = ("0-first-run-storyboard", FirstRunStoryboard.size,
                                  AnyView(FirstRunStoryboard(theme: theme, coat: coat)))
                for (name, size, page) in [storyboard] + pages.map({ ($0.0, onboardingWindowSize, $0.1) }) {
                    // Drawn through AppKit in a window kept off screen, so buttons look as they do on screen.
                    // (Settings pages stay blank this way: a Form lays out no rows off screen.)
                    let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20_000, y: 0), size: size),
                                          styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
                    let host = NSHostingView(rootView: page.frame(width: size.width, height: size.height).localized())
                    window.contentView = host
                    window.orderFrontRegardless()
                    try? await Task.sleep(for: .seconds(1.5))
                    if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                        host.cacheDisplay(in: host.bounds, to: rep)
                        try? rep.representation(using: .png, properties: [:])?
                            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("onboarding-\(name).png"))
                    }
                    window.orderOut(nil)
                }
                NSApp.terminate(nil)
            }
            return
        }
        Task { @MainActor in
            await ChuruModel.shared.refresh()
            await CostUsageModel.shared.refresh()
            await UsageLimitsModel.shared.refresh()
            let size = CGSize(width: 640, height: companionStoreNotchHeight - 40)
            let store = StoreModel.shared
            let pages: [(String, AnyView)] = [
                ("store-main", AnyView(StoreView())),
                ("store-adopt", AnyView(StoreView())),
                ("my-cats", AnyView(MyCatsView())),
                ("home-ledger", AnyView(HomeLedgerView(theme: store.theme(id: AppSettings.roomThemeID), display: UIDisplayModel.shared.settings.home)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(store.theme(id: AppSettings.roomThemeID)
                        .panel.swiftUI)
                    .frame(width: 616))),
            ]
            for (name, view) in pages {
                switch name {
                case "store-adopt": store.route = .adopt
                default: store.route = .main
                }
                // Each page is its own SwiftUI root, so it takes the chosen language the way the notch does.
                let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
                    .background(Color.black).environment(\.colorScheme, .dark).localized())
                renderer.scale = 2
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
                }
            }
            store.route = .main
            NSApp.terminate(nil)
        }
    }
}
#endif
