import Foundation

/// Connecting Claude Code and Codex: the same steps from Settings › Agents and from the first-run window.
/// Each call returns what to tell the user; `ok` is false when nothing changed.
enum AgentSetup {
    struct Outcome {
        let ok: Bool
        let notice: LocalizedStringResource
    }

    static func integration(for provider: AgentProvider) -> HookIntegration {
        provider == .codex ? .codex : .claude
    }

    static func state(of provider: AgentProvider) -> AgentSetupState {
        let integration = integration(for: provider)
        let folder = integration.file.url.deletingLastPathComponent().path
        return AgentSetupState(folderExists: FileManager.default.fileExists(atPath: folder),
                               hookInstalled: integration.isInstalled(),
                               pythonUsable: integration.pythonIsUsable())
    }

    /// Installs the hook that reports session events.
    static func connectHook(_ integration: HookIntegration, name: String) -> Outcome {
        guard let script = Bundle.main.url(forResource: "tokencats-hook", withExtension: "py") else {
            return Outcome(ok: false, notice: "The hook script is missing from the app")
        }
        do {
            try integration.install(bundledScript: script)
        } catch HookIntegration.Failure.agentNotInstalled {
            return Outcome(ok: false, notice: "The \(name) settings folder is missing")
        } catch HookIntegration.Failure.invalidConfig {
            return Outcome(ok: false, notice: "The \(name) settings file is not valid JSON, so it was left alone")
        } catch HookIntegration.Failure.pythonUnavailable {
            return Outcome(ok: false, notice: "Xcode Command Line Tools are missing, so nothing was connected. Run xcode-select --install in Terminal, then connect again")
        } catch {
            return Outcome(ok: false, notice: "Could not set up \(name): \(error.localizedDescription)")
        }
        return Outcome(ok: true, notice: integration.agent.provider == .codex
            ? "In Codex, approve it with /hooks, then start a new session"
            : "Applies from the next Claude session")
    }

    static func connectLimits() -> Outcome {
        guard let script = Bundle.main.url(forResource: "tokencats-statusline", withExtension: "py") else {
            return Outcome(ok: false, notice: "The status line script is missing from the app")
        }
        do {
            try StatusLineIntegration.claude.install(bundledScript: script)
        } catch HookIntegration.Failure.agentNotInstalled {
            return Outcome(ok: false, notice: "The Claude settings folder is missing")
        } catch HookIntegration.Failure.invalidConfig {
            return Outcome(ok: false, notice: "The Claude settings file is not valid JSON, so it was left alone")
        } catch StatusLineIntegration.Failure.pythonUnavailable {
            return Outcome(ok: false, notice: "Not connected: the Xcode command line tools are missing. Run xcode-select --install in Terminal, then connect again")
        } catch {
            return Outcome(ok: false, notice: "Could not set up Claude limits: \(error.localizedDescription)")
        }
        return Outcome(ok: true, notice: "Claude limits connected. They show from the next Claude response")
    }
}
