import SwiftUI

extension AgentProvider {
    /// The colour that marks each agent in the app: Claude orange, Codex green.
    var badgeColor: Color {
        switch self {
        case .claude: return Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
        case .codex: return Color(red: 0x10 / 255, green: 0xA3 / 255, blue: 0x7F / 255)
        }
    }
}

/// Settings › Agents: install or remove the Claude Code and Codex hooks, wrap the status line for Claude limits,
/// and write the profile SVG.
/// Hooks only drive closed-notch session alerts; token usage and churu are read from the agents' logs without them.
struct AgentConnectionSettings: View {
    @State private var claudeInstalled = HookIntegration.claude.isInstalled()
    @State private var codexInstalled = HookIntegration.codex.isInstalled()
    @State private var notice: LocalizedStringResource?
    @State private var limitsInstalled = StatusLineIntegration.claude.isInstalled()

    var body: some View {
        Form {
            Section {
                connectionRow("Claude Code", installed: $claudeInstalled, integration: .claude,
                              color: AgentProvider.claude.badgeColor)
                connectionRow("Codex", installed: $codexInstalled, integration: .codex,
                              color: AgentProvider.codex.badgeColor)
            } header: {
                Text("Agent hooks")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let notice { Text(notice) }
                    Text("The hook lets TokenCats follow each session's events. Tokens and churu are counted without it.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                HStack {
                    Text("Claude status line")
                    Spacer()
                    Button(limitsInstalled ? "Disconnect" : "Connect") { toggleLimits() }
                }
            } header: {
                Text("Claude limits")
            } footer: {
                Text("Wraps the Claude Code status line to read the official usage. Your existing status line stays as it is.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Agents")
    }

    private func toggleLimits() {
        let integration = StatusLineIntegration.claude
        if limitsInstalled {
            do {
                try integration.uninstall()
                notice = "Claude limits disconnected; the original status line is back"
            } catch HookIntegration.Failure.invalidConfig {
                notice = "The Claude settings file is not valid JSON, so it was left alone"
            } catch {
                notice = "Could not set up Claude limits: \(error.localizedDescription)"
            }
        } else {
            notice = AgentSetup.connectLimits().notice
        }
        limitsInstalled = integration.isInstalled()
    }

    private func connectionRow(
        _ name: String, installed: Binding<Bool>, integration: HookIntegration, color: Color
    ) -> some View {
        HStack {
            Circle()
                .fill(installed.wrappedValue ? color : .clear)
                .overlay(Circle().stroke(installed.wrappedValue ? color : .gray, lineWidth: 1))
                .frame(width: 8, height: 8)
            Text(name)
            Spacer()
            Button(installed.wrappedValue ? "Disconnect" : "Connect") {
                toggle(name, installed: installed, integration: integration)
            }
        }
    }

    private func toggle(_ name: String, installed: Binding<Bool>, integration: HookIntegration) {
        if installed.wrappedValue {
            do {
                try integration.uninstall()
                notice = "\(name) hook removed"
            } catch HookIntegration.Failure.invalidConfig {
                notice = "The \(name) settings file is not valid JSON, so it was left alone"
            } catch {
                notice = "Could not set up \(name): \(error.localizedDescription)"
            }
        } else {
            notice = AgentSetup.connectHook(integration, name: name).notice
        }
        installed.wrappedValue = integration.isInstalled()
    }
}
