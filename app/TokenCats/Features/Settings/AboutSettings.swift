// Adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import SwiftUI

/// 정보: version and where the notch shell comes from.
struct AboutSettings: View {
    @State private var showBuildNumber = false

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
