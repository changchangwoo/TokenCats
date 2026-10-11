import LaunchAtLogin
import SwiftUI

/// 일반: language and launch at login.
struct GeneralSettings: View {
    @ObservedObject private var language = AppLanguage.shared

    var body: some View {
        Form {
            Section("Language") {
                // The list is the bundle's languages: a new translation shows up here on its own.
                Picker("Language", selection: $language.selection) {
                    Text("Follow system").tag(AppLanguage.systemSelection)
                    ForEach(language.available) { Text(verbatim: $0.name).tag($0.code) }
                }
            }
            Section("Startup") {
                LaunchAtLogin.Toggle("Launch at login")
            }
        }
        .navigationTitle("General")
    }
}
