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
                Text("Session alerts")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let notice { Text(notice) }
                    Text("With the hook connected, sessions waiting for a response show in the closed notch. Tokens and churu are counted without it.")
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
        do {
            if limitsInstalled {
                try integration.uninstall()
                notice = "Claude limits disconnected; the original status line is back"
            } else {
                guard let script = Bundle.main.url(forResource: "tokencats-statusline", withExtension: "py") else {
                    notice = "The status line script is missing from the app"
                    return
                }
                try integration.install(bundledScript: script)
                notice = "Claude limits connected. They show from the next Claude response"
            }
        } catch HookIntegration.Failure.agentNotInstalled {
            notice = "The Claude settings folder is missing"
        } catch HookIntegration.Failure.invalidConfig {
            notice = "The Claude settings file is not valid JSON, so it was left alone"
        } catch StatusLineIntegration.Failure.pythonUnavailable {
            notice = "Not connected: the Xcode command line tools are missing. Run xcode-select --install in Terminal, then connect again"
        } catch {
            notice = "Could not set up Claude limits: \(error.localizedDescription)"
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
        do {
            if installed.wrappedValue {
                try integration.uninstall()
                notice = "\(name) hook removed"
            } else {
                guard let script = Bundle.main.url(forResource: "tokencats-hook", withExtension: "py") else {
                    notice = "The hook script is missing from the app"
                    return
                }
                try integration.install(bundledScript: script)
                notice = integration.agent.provider == .codex
                    ? "In Codex, approve it with /hooks, then start a new session"
                    : "Applies from the next Claude session"
            }
        } catch HookIntegration.Failure.agentNotInstalled {
            notice = "The \(name) settings folder is missing"
        } catch HookIntegration.Failure.invalidConfig {
            notice = "The \(name) settings file is not valid JSON, so it was left alone"
        } catch HookIntegration.Failure.pythonUnavailable {
            notice = "Xcode Command Line Tools are missing, so nothing was connected. Run xcode-select --install in Terminal, then connect again"
        } catch {
            notice = "Could not set up \(name): \(error.localizedDescription)"
        }
        installed.wrappedValue = integration.isInstalled()
    }
}
