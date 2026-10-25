// Adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import SwiftUI

/// The settings window: TokenCats' own screens first, then what is left of the notch shell.
struct SettingsView: View {
    @State private var selectedTab = "CompanionGeneral"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("TokenCats") {
                    NavigationLink(value: "CompanionGeneral") { Label("General", systemImage: "gear") }
                    NavigationLink(value: "Home") { Label("Home display", systemImage: "house") }
                    if ShellLaunch.mode == .notch {
                        NavigationLink(value: "ClosedNotch") { Label("Closed notch", systemImage: "pawprint") }
                    }
                    NavigationLink(value: "Performance") { Label("Performance", systemImage: "bolt.badge.clock") }
                    NavigationLink(value: "Agents") { Label("Agents", systemImage: "terminal") }
                    NavigationLink(value: "Profile") { Label("GitHub profile", systemImage: "person.crop.square") }
                    NavigationLink(value: "Data") { Label("Data", systemImage: "externaldrive") }
                }
                Section("Advanced") {
                    if ShellLaunch.mode == .notch {
                        NavigationLink(value: "Notch") { Label("Notch", systemImage: "macbook") }
                    }
                    #if DEBUG
                    NavigationLink(value: "Developer") { Label("Developer", systemImage: "hammer") }
                    #endif
                    NavigationLink(value: "About") { Label("About", systemImage: "info.circle") }
                }
            }
            .listStyle(SidebarListStyle())
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case "Home": HomeDisplaySettingsView()
                case "ClosedNotch": ClosedNotchSettings()
                case "Performance": PerformanceSettings()
                case "Agents": AgentConnectionSettings()
                case "Profile": ProfileSettings()
                case "Data": DataSettings()
                case "Notch": NotchSettings()
                case "Developer": DeveloperSettings()
                case "About": AboutSettings()
                default: GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("").frame(width: 0, height: 0).accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
