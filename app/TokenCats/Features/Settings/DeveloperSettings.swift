import SwiftUI

/// Developer options that only matter while building the app.
struct DeveloperSettings: View {
    @AppStorage(AppSettings.Key.storeFreeForTesting) private var freeForTesting = AppSettings.storeFreeForTesting

    var body: some View {
        Form {
            Section {
                Toggle("Store test mode (everything free)", isOn: $freeForTesting)
                Button("Restart app") { Relaunch.now() }
            } footer: {
                Text("Every store price becomes 0 churu and churu is never spent. Takes effect after the app restarts.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Developer")
    }
}
