import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

/// 일반: language, where the app lives (notch or menu bar) and launch at login.
struct GeneralSettings: View {
    @ObservedObject private var language = AppLanguage.shared
    @ObservedObject private var coordinator = NotchCoordinator.shared
    @AppStorage(AppSettings.Key.shellPreference) private var shellPreference = ShellPreference.default.rawValue

    /// The shell the stored choice would run, against the one running now: they differ until a relaunch.
    private var needsRestart: Bool {
        let chosen = ShellPreference(rawValue: shellPreference) ?? .default
        return chosen.resolve(hasNotchDisplay: ShellLaunch.hasNotchDisplay, lastMode: ShellLaunch.mode) != ShellLaunch.mode
    }

    var body: some View {
        Form {
            Section("Language") {
                // The list is the bundle's languages: a new translation shows up here on its own.
                Picker("Language", selection: $language.selection) {
                    Text("Follow system").tag(AppLanguage.systemSelection)
                    ForEach(language.available) { Text(verbatim: $0.name).tag($0.code) }
                }
            }
            Section {
                Picker("Show TokenCats in", selection: $shellPreference) {
                    Text("Automatic").tag(ShellPreference.automatic.rawValue)
                    Text("Notch").tag(ShellPreference.notch.rawValue)
                    Text("Menu bar").tag(ShellPreference.menuBar.rawValue)
                }
                if ShellLaunch.mode == .menuBar {
                    // The Notch page is hidden in this mode; these are the settings from it the panel still reads.
                    KeyboardShortcuts.Recorder("Open or close the panel", name: .toggleNotchOpen)
                    Toggle("Remember the last tab", isOn: $coordinator.openLastTabByDefault)
                    Defaults.Toggle(key: .hideFromScreenRecording) { Text("Hide from screen recording") }
                }
                if needsRestart {
                    Button("Restart to apply") { Relaunch.now() }
                }
            } footer: {
                Text("Automatic uses the notch on a Mac with a camera notch and the menu bar everywhere else, where a drawn notch would cover browser tabs.")
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                LaunchAtLogin.Toggle("Launch at login")
            }
            Section {
                Button("Show first-run setup again") {
                    NotificationCenter.default.post(name: .showOnboardingRequested, object: nil)
                }
            } footer: {
                Text("Connect agents, Claude limits and the GitHub card step by step.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("General")
    }
}
