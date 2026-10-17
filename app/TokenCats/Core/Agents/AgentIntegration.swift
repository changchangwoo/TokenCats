import Foundation

/// A coding agent TokenCats can watch. Adding one is a case here, its settings file, and the events its hooks
/// fire; the hook script (`tokencats-hook.py`) reads the provider name from its argument.
enum AgentIntegration: CaseIterable, Sendable {
    case claudeCode, codex

    var provider: AgentProvider {
        switch self {
        case .claudeCode: return .claude
        case .codex: return .codex
        }
    }

    /// The JSON file that lists hooks.
    var hooksFile: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .claudeCode: return home.appendingPathComponent(".claude/settings.json")
        case .codex: return home.appendingPathComponent(".codex/hooks.json")
        }
    }

    /// Hook events we register. Codex has no `SessionEnd`.
    var hookEvents: [HookConfigMerger.Registration] {
        let common: [HookConfigMerger.Registration] = [
            .init(event: "SessionStart", matcher: nil, timeout: 5),
            .init(event: "UserPromptSubmit", matcher: nil, timeout: 5),
            .init(event: "PreToolUse", matcher: "*", timeout: 5),
            .init(event: "PostToolUse", matcher: "*", timeout: 5),
            .init(event: "PermissionRequest", matcher: "*", timeout: 130),
            .init(event: "Stop", matcher: nil, timeout: 5),
        ]
        switch self {
        case .claudeCode: return common + [
            .init(event: "StopFailure", matcher: nil, timeout: 5),
            .init(event: "SessionEnd", matcher: nil, timeout: 5),
        ]
        case .codex: return common
        }
    }

    /// Only Claude Code has a `statusLine` to wrap for rate limits.
    var supportsStatusLine: Bool { self == .claudeCode }
}
