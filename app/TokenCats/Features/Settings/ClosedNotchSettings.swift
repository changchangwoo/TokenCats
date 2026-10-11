import SwiftUI

/// 닫힌 노치: the room's cats beside the closed notch.
struct ClosedNotchSettings: View {
    @AppStorage(AppSettings.Key.closedNotchCats) private var cats = AppSettings.Default.closedNotchCats

    var body: some View {
        Form {
            Section {
                Toggle("Show room cats", isOn: $cats)
            } footer: {
                Text("When the notch is closed, the cats in the room sit beside it, two on each side. The black area widens to fit them.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Closed notch")
    }
}
