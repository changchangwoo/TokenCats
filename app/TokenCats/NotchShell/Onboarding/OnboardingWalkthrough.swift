#if DEBUG
import LaunchAtLogin
import SwiftUI

/// Debug builds only: with `NC_SNAPSHOT_DIR` and `NC_ONBOARDING_WALKTHROUGH=1`, drives the real first-run flow the
/// way a person would (next, back, skip, finish), draws every page with this Mac's real states, and writes
/// `walkthrough.txt` with each check. It never presses a button that changes another app's settings or GitHub:
/// connect, turn on, and README stay untouched. The `firstLaunch` flag it flips is put back afterwards.
@MainActor
enum OnboardingWalkthrough {
    static func run(dir: URL) async {
        var lines: [String] = []
        var failures = 0
        func check(_ ok: Bool, _ what: String) {
            lines.append((ok ? "PASS " : "FAIL ") + what)
            if !ok { failures += 1 }
        }

        let savedFirstLaunch = NotchCoordinator.shared.firstLaunch
        let loginBefore = LaunchAtLogin.isEnabled
        var closed = 0, openedRoom = 0
        let model = OnboardingModel(onClose: { closed += 1 }, onOpenCatRoom: { openedRoom += 1 })
        lines.append("agents: claude=\(model.claude) codex=\(model.codex) limitsOn=\(model.limitsOn)")
        lines.append("pages: \(model.pages)")

        check(model.page == .welcome, "starts on the welcome page")
        check(model.pages == OnboardingPlan.pages(claudePresent: model.claude != .notInstalled),
              "pages follow the plan for this Mac")

        // Forward through every page, drawing each one as the window shows it.
        var visited: [OnboardingStepKind] = []
        for _ in model.pages {
            visited.append(model.page)
            await draw(model, name: "\(visited.count)-\(model.page)", dir: dir)
            check(model.progress.step == visited.count && model.progress.total == model.pages.count,
                  "progress dots say \(visited.count)/\(model.pages.count) on \(model.page)")
            if model.page == .finish { break }
            if model.page == .loginItem {
                // Next applies the switch; keep it at what the Mac has so nothing changes.
                model.launchAtLogin = LaunchAtLogin.isEnabled
            }
            model.next()
        }
        check(visited == model.pages, "next walks every page in order")
        check(!NotchCoordinator.shared.firstLaunch, "leaving the welcome page lets the notch open on hover")
        check(LaunchAtLogin.isEnabled == loginBefore, "walking through left launch at login as it was")

        // Back, then skip the login page with the switch flipped: skip must not apply it.
        model.back()
        check(model.page == .loginItem, "back returns to the launch-at-login page")
        model.launchAtLogin = !LaunchAtLogin.isEnabled
        model.skip()
        check(model.page == .finish, "skip moves on")
        check(LaunchAtLogin.isEnabled == loginBefore, "skip did not change launch at login")

        // Back past the start does nothing.
        for _ in model.pages { model.back() }
        check(model.page == .welcome, "back stops at the welcome page")

        check(!model.summary.isEmpty, "finish summary lists \(model.summary.count) items")
        model.finish()
        check(closed == 1 && openedRoom == 1, "finish closes the window and opens the cat room")

        let skipping = OnboardingModel(onClose: { closed += 1 }, onOpenCatRoom: { openedRoom += 1 })
        skipping.skipAll()
        check(closed == 2 && openedRoom == 1, "skip on the welcome page closes without opening the room")

        NotchCoordinator.shared.firstLaunch = savedFirstLaunch
        lines.append(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
        try? lines.joined(separator: "\n").write(to: dir.appendingPathComponent("walkthrough.txt"),
                                                 atomically: true, encoding: .utf8)
    }

    /// The page as the real window draws it, through AppKit in a window kept off screen.
    private static func draw(_ model: OnboardingModel, name: String, dir: URL) async {
        let size = onboardingWindowSize
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20_000, y: 0), size: size),
                              styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: OnboardingFlowView(model: model).localized())
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(model.page == .github ? 4 : 1.2))
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
        }
        window.orderOut(nil)
    }
}
#endif
