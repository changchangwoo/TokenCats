import AppKit
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
    private var outsideClickMonitor: Any?
    private var otherWindowObserver: NSObjectProtocol?

    // MARK: - CompanionShell

    func start() {
        // No notch, so no hello scene in it.
        NotchCoordinator.shared.helloAnimationRunning = false
        panel.contentView = NSHostingView(rootView: MenuBarPanelView().environmentObject(vm).localized())

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.setAccessibilityLabel("TokenCats")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        // Settings or onboarding coming forward closes the panel instead of hiding under it.
        otherWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self, let window, window !== self.panel else { return }
                self.hide()
            }
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

    private var isShown: Bool { panel.isVisible }

    private func toggle() { isShown ? hide() : show() }

    private func show() {
        guard !isShown, let button = statusItem?.button, let buttonWindow = button.window else { return }
        let iconFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrameOrigin(MenuBarPanelPlacement.origin(iconMidX: iconFrame.midX, visibleFrame: visible,
                                                          panelSize: MenuBarPanel.size))
        vm.open()
        panel.orderFrontRegardless()
        panel.makeKey()
        button.highlight(true)
        // Global monitors see only clicks that go to other apps, including clicks on the panel's transparent area.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.hide() }
        }
    }

    private func hide() {
        guard isShown else { return }
        panel.orderOut(nil)
        vm.close()
        statusItem?.button?.highlight(false)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
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
