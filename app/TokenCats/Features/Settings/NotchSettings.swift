// Adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import Defaults
import KeyboardShortcuts
import SwiftUI

/// 노치: the notch window itself — where it shows, how tall it is, how it opens, and its look.
/// Inherited from boring.notch's General · Appearance · Shortcuts · Advanced tabs, kept to what the shell still reads.
/// `Defaults.Toggle` only takes a plain `String` title, so every toggle gets its label as `Text` to go through the catalog.
struct NotchSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NotchSettings.currentScreens()
    @ObservedObject var coordinator = NotchCoordinator.shared

    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.nonNotchHeight) var nonNotchHeight
    @Default(.openNotchOnHover) var openNotchOnHover
    @Default(.minimumHoverDuration) var minimumHoverDuration
    @Default(.enableGestures) var enableGestures
    @Default(.gestureSensitivity) var gestureSensitivity

    var body: some View {
        Form {
            displaySection
            sizingSection
            behaviourSection
            gestureSection
            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Open or close the notch", name: .toggleNotchOpen)
            }
            Section("Window") {
                Defaults.Toggle(key: .enableShadow) { Text("Window shadow") }
                Defaults.Toggle(key: .cornerRadiusScaling) { Text("Rounder corners when open") }
                Defaults.Toggle(key: .settingsIconInNotch) { Text("Settings icon in the notch") }
                Defaults.Toggle(key: .hideTitleBar) { Text("Hide the gap below the menu bar") }
                Defaults.Toggle(key: .showOnLockScreen) { Text("Show on the lock screen") }
                Defaults.Toggle(key: .hideFromScreenRecording) { Text("Hide from screen recording") }
                Defaults.Toggle(key: .hideOnFullscreen) { Text("Hide over full-screen apps") }
            }
        }
        .navigationTitle("Notch")
        .onChange(of: openNotchOnHover) { if !openNotchOnHover { enableGestures = true } }
    }

    private var displaySection: some View {
        Section("Display") {
            Defaults.Toggle(key: .menubarIcon) { Text("Menu bar icon") }
            Defaults.Toggle(key: .showOnAllDisplays) { Text("Show on all displays") }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(name: .showOnAllDisplaysChanged, object: nil)
                }
            Picker("Preferred display", selection: $coordinator.preferredScreenUUID) {
                ForEach(screens, id: \.uuid) { Text($0.name).tag($0.uuid as String?) }
            }
            .onChange(of: NSScreen.screens) { screens = Self.currentScreens() }
            .disabled(showOnAllDisplays)
            Defaults.Toggle(key: .automaticallySwitchDisplay) { Text("Switch displays automatically") }
                .onChange(of: automaticallySwitchDisplay) {
                    NotificationCenter.default.post(name: .automaticallySwitchDisplayChanged, object: nil)
                }
                .disabled(showOnAllDisplays)
        }
    }

    private var sizingSection: some View {
        Section("Height") {
            Picker("Displays with a notch", selection: $notchHeightMode) {
                Text("Real notch height").tag(WindowHeightMode.matchRealNotchSize)
                Text("Menu bar height").tag(WindowHeightMode.matchMenuBar)
                Text("Custom").tag(WindowHeightMode.custom)
            }
            .onChange(of: notchHeightMode) {
                notchHeight = notchHeightMode == .matchMenuBar ? 44 : 38
                NotificationCenter.default.post(name: .notchHeightChanged, object: nil)
            }
            if notchHeightMode == .custom {
                Slider(value: $notchHeight, in: 15...45, step: 1) { Text("Height \(notchHeight, specifier: "%.0f")") }
                    .onChange(of: notchHeight) { NotificationCenter.default.post(name: .notchHeightChanged, object: nil) }
            }
            Picker("Displays without a notch", selection: $nonNotchHeightMode) {
                Text("Menu bar height").tag(WindowHeightMode.matchMenuBar)
                Text("Real notch height").tag(WindowHeightMode.matchRealNotchSize)
                Text("Custom").tag(WindowHeightMode.custom)
            }
            .onChange(of: nonNotchHeightMode) {
                nonNotchHeight = nonNotchHeightMode == .matchMenuBar ? 24 : 32
                NotificationCenter.default.post(name: .notchHeightChanged, object: nil)
            }
            if nonNotchHeightMode == .custom {
                Slider(value: $nonNotchHeight, in: 0...40, step: 1) { Text("Height \(nonNotchHeight, specifier: "%.0f")") }
                    .onChange(of: nonNotchHeight) { NotificationCenter.default.post(name: .notchHeightChanged, object: nil) }
            }
        }
    }

    private var behaviourSection: some View {
        Section("Opening") {
            Defaults.Toggle(key: .openNotchOnHover) { Text("Open on hover") }
            if openNotchOnHover {
                Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                    HStack {
                        Text("Hover delay")
                        Spacer()
                        Text("\(minimumHoverDuration, specifier: "%.1f") s").foregroundStyle(.secondary)
                    }
                }
            }
            Defaults.Toggle(key: .enableHaptics) { Text("Haptic feedback") }
            Toggle("Remember the last tab", isOn: $coordinator.openLastTabByDefault)
        }
    }

    private var gestureSection: some View {
        Section {
            Defaults.Toggle(key: .enableGestures) { Text("Use gestures") }.disabled(!openNotchOnHover)
            if enableGestures {
                Slider(value: $gestureSensitivity, in: 100...300, step: 100) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(gestureSensitivity == 100 ? "High" : gestureSensitivity == 200 ? "Medium" : "Low")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Gestures")
        } footer: {
            Text("Swipe down on the notch with two fingers to open it.").foregroundStyle(.secondary)
        }
    }

    private static func currentScreens() -> [(uuid: String, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let uuid = screen.displayUUID else { return nil }
            return (uuid, screen.localizedName)
        }
    }
}
