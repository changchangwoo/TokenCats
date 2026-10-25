import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI

/// Menu bar mode: the status item, its panel and its menu. Left-click toggles the panel; right-click or
/// Control-click shows the app menu, the only way to quit since the app has no Dock icon.
@MainActor
final class MenuBarShellController: NSObject, CompanionShell {
    private var statusItem: NSStatusItem?
    private let panel = MenuBarPanel()
    /// The panel's own model: `open()` on show, `close()` on hide, so Home's resizing and "Remember the last tab"
    /// work as in the notch.
    private let vm = NotchViewModel()
    /// The panel's state as this controller set it; `panel.isVisible` alone can drift from it.
    private var isOpen = false
    private var outsideClickMonitor: Any?
    private var otherWindowObserver: NSObjectProtocol?
    private var sizeObserver: AnyCancellable?

    // MARK: - CompanionShell

    func start() {
        // No notch, so no hello scene in it.
        NotchCoordinator.shared.helloAnimationRunning = false
        let host = NSHostingView(rootView: MenuBarPanelView().environmentObject(vm).localized())
        // The window keeps its fixed size; the SwiftUI content must not resize it.
        host.sizingOptions = []
        panel.contentView = host

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.setAccessibilityLabel("TokenCats")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        // Settings or onboarding coming forward closes the panel instead of hiding under it. Alerts, sheets and
        // popovers the panel's own screens open are panels or attached windows, and leave it open.
        otherWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self, let window, Self.isAppWindow(window) else { return }
                self.hide()
            }
        }
        // Each tab has its own height and Home grows with its sections. The panel animates downward inside the
        // fixed window; once it settles, the system shadow is recomputed around the new shape.
        sizeObserver = vm.$notchSize
            .removeDuplicates()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.panel.invalidateShadow() }
            }
        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
    }

    func stop() {
        hide()
        if let observer = otherWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            otherWindowObserver = nil
        }
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    func openCompanion() { show() }

    /// No scene to play first: the onboarding window opens right away.
    func beginFirstRun(showOnboarding: @escaping @MainActor @Sendable () -> Void) {
        showOnboarding()
    }

    // MARK: - Panel

    private func toggle() { isOpen ? hide() : show() }

    /// A titled, free-standing app window such as Settings or onboarding.
    private static func isAppWindow(_ window: NSWindow) -> Bool {
        window.styleMask.contains(.titled) && !(window is NSPanel) && window.sheetParent == nil && window.parent == nil
    }

    private func show() {
        guard !isOpen, let button = statusItem?.button else { return }
        guard let frame = frame() else { return }
        isOpen = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        // Content goes in once the window is on screen, so its unrolling animation is seen from the start.
        vm.open()
        // After the click's own mouse-up, which would clear the highlight again.
        DispatchQueue.main.async { button.highlight(true) }
        // Global monitors see only clicks that go to other apps.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.hide() }
        }
    }

    private func hide() {
        guard isOpen else { return }
        isOpen = false
        statusItem?.button?.highlight(false)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        // Closing is immediate, like a system menu.
        panel.orderOut(nil)
        vm.close()
    }

    /// The window's frame under the icon, on the icon's screen.
    private func frame() -> NSRect? {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return nil }
        let icon = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let origin = MenuBarPanelPlacement.origin(icon: icon, visibleFrame: visible, panelSize: MenuBarPanel.size)
        return NSRect(origin: origin, size: MenuBarPanel.size)
    }

    // MARK: - Menu

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            toggle()
        }
    }

    /// The same items as the notch mode's menu bar menu (`TokenCatsApp.menu`).
    private func showMenu() {
        hide()
        guard let button = statusItem?.button else { return }
        let language = AppLanguage.shared
        let menu = NSMenu()
        menu.addItem(item(language.string("Settings"), #selector(openSettings), key: ","))
        if let version = AppUpdater.shared.pendingVersion {
            menu.addItem(item(language.string("Update to TokenCats \(version)…"), #selector(checkForUpdates)))
        } else {
            menu.addItem(item(language.string("Check for Updates…"), #selector(checkForUpdates)))
        }
        menu.addItem(.separator())
        menu.addItem(item(language.string("Restart TokenCats"), #selector(restart)))
        menu.addItem(item(language.string("Quit"), #selector(quit), key: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openSettings() { SettingsWindowController.shared.showWindow() }
    @objc private func checkForUpdates() { AppUpdater.shared.checkForUpdates() }
    @objc private func restart() { Relaunch.now() }
    @objc private func quit() { NSApp.terminate(nil) }
}
