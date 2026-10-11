import AppKit
import SwiftUI

/// Controls only what Home draws; agent connections and notch behavior stay in their own settings.
struct HomeDisplaySettingsView: View {
    @ObservedObject private var model = UIDisplayModel.shared

    var body: some View {
        Form {
            Section("Churu ledger") {
                Toggle("Churu balance", isOn: choice(\.showBalance))
                Toggle("Today's tokens", isOn: choice(\.showTodayTokens))
                Toggle("Show cost", isOn: choice(\.showEstimatedCost))
                Toggle("Streak", isOn: choice(\.showStreak))
                Toggle("Progress to the next adoption", isOn: choice(\.showAdoptionProgress))
            }
            Section("Agent limits") {
                Toggle("Show the limits section", isOn: choice(\.showAgentLimits))
                ForEach(UsageLimitsModel.shared.sources, id: \.id) { source in
                    Toggle(source.name, isOn: providerVisible(source.id))
                }
                Toggle("Usage figures", isOn: choice(\.showUsageValues))
                Toggle("Usage bars", isOn: choice(\.showUsageBars))
                Toggle("Time until reset", isOn: choice(\.showResetTime))
            }
            Section("Usage history") {
                Toggle("Last 7 days on Home", isOn: choice(\.showWeeklyTokens))
                Toggle("7-day chart in Statistics", isOn: choice(\.showWeeklyChart))
                Toggle("365-day graph in Statistics", isOn: choice(\.showContributionGraph))
            }
            Section {
                HStack {
                    Text("Settings file")
                    Spacer()
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.fileURL])
                    }
                }
            } footer: {
                Text("Changes made in the file apply when Home is reopened. The notch height follows the sections that are on.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Home display")
        .onAppear { model.reload() }
    }

    private func choice(_ keyPath: WritableKeyPath<HomeDisplaySettings, Bool>) -> Binding<Bool> {
        Binding(get: { model.settings.home[keyPath: keyPath] },
                set: { value in model.updateHome { $0[keyPath: keyPath] = value } })
    }

    private func providerVisible(_ id: String) -> Binding<Bool> {
        Binding(get: { !model.settings.home.hiddenProviderIDs.contains(id) },
                set: { visible in
                    model.updateHome { settings in
                        settings.hiddenProviderIDs.removeAll { $0 == id }
                        if !visible { settings.hiddenProviderIDs.append(id) }
                    }
                })
    }
}
