import SwiftUI

/// GitHub 프로필: connection and README (as before), what the card shows, and when it uploads.
struct ProfileSettings: View {
    @AppStorage(AppSettings.Key.profileShowsNumbers) private var showsNumbers = AppSettings.Default.profileShowsNumbers
    @AppStorage(AppSettings.Key.profileShowsYear) private var showsYear = AppSettings.Default.profileShowsYear
    @AppStorage(AppSettings.Key.profileSyncMode) private var syncMode = AppSettings.Default.profileSyncMode
    @ObservedObject private var sync = ProfileSync.shared
    @State private var notice: LocalizedStringResource?

    var body: some View {
        Form {
            GitHubConnectSection()
            Section {
                Toggle("Contribution graph and streak", isOn: $showsYear)
                Toggle("Token numbers", isOn: $showsNumbers)
            } header: {
                Text("Card contents")
            } footer: {
                Text("The cat room is always included.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Auto-update", selection: $syncMode) {
                    Text("Once a day and when the room changes").tag(ProfileSyncMode.changes.rawValue)
                    Text("Once a day").tag(ProfileSyncMode.daily.rawValue)
                    Text("Only when updated manually").tag(ProfileSyncMode.manual.rawValue)
                }
                Button(sync.busy ? "Uploading…" : "Update now") {
                    Task {
                        await sync.sync()
                        notice = sync.state.lastError.map { "Update failed: \($0)" as LocalizedStringResource } ?? "Card uploaded"
                    }
                }
                .disabled(sync.busy || !sync.state.isConnected)
            } header: {
                Text("Update")
            } footer: {
                if let notice { Text(notice) }
            }
            ProfileExportSection()
        }
        .navigationTitle("GitHub profile")
    }
}
