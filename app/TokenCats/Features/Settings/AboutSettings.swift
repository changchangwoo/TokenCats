// Adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import SwiftUI

/// 정보: version, updates, and where the notch shell comes from.
struct AboutSettings: View {
    @State private var showBuildNumber = false
    @ObservedObject private var updater = AppUpdater.shared

    var body: some View {
        Form {
            Section("Version") {
                HStack {
                    Text("Version")
                    Spacer()
                    if showBuildNumber { Text("(\(Bundle.main.buildVersionNumber ?? ""))").foregroundStyle(.secondary) }
                    Text(Bundle.main.releaseVersionNumber ?? "-").foregroundStyle(.secondary)
                }
                .onTapGesture { withAnimation { showBuildNumber.toggle() } }
            }
            Section {
                Toggle("Check for updates automatically", isOn: $updater.automaticChecks)
                LabeledContent("Last checked") {
                    if let date = updater.lastCheck {
                        Text(date, format: .relative(presentation: .named))
                    } else {
                        Text("Never")
                    }
                }
                Button("Check for Updates…") { updater.checkForUpdates() }.disabled(!updater.canCheck)
            } header: {
                Text("Updates")
            } footer: {
                Text("Looks for a new version on github.com once a day and asks before installing anything.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    // Credit: TokenCats is built on boring.notch (GPL-3.0)
                    if let url = URL(string: "https://github.com/TheBoredTeam/boring.notch") { NSWorkspace.shared.open(url) }
                } label: {
                    Label("Built on boring.notch (GPL-3.0)", image: "Github")
                }
                .buttonStyle(.plain)
            } header: {
                Text("Credits")
            }
        }
        .navigationTitle("About")
    }
}
