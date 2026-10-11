import SwiftUI

/// 닫힌 노치: the room's cats beside the closed notch and session alerts (off by default).
struct ClosedNotchSettings: View {
    @AppStorage(AppSettings.Key.closedNotchCats) private var cats = AppSettings.Default.closedNotchCats
    @AppStorage(AppSettings.Key.sessionAlerts) private var sessionAlerts = AppSettings.Default.sessionAlerts

    var body: some View {
        Form {
            Section {
                Toggle("Show room cats", isOn: $cats)
            } footer: {
                Text("When the notch is closed, the cats in the room sit beside it, two on each side. The black area widens to fit them.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Session alerts", isOn: $sessionAlerts).disabled(!cats)
            } footer: {
                Text("When an agent session is waiting for a response, a dot appears above a cat: orange needs approval, red is an error, white is a new result. Click that cat to go to the terminal.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Closed notch")
    }
}
