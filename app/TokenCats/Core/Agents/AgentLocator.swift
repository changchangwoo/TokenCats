import Foundation

/// Finds the claude/codex process that ran a hook, and checks whether it still lives.
struct AgentLocator: Sendable {
    static let maxDepth = 8

    let inspector: any ProcessInspector

    func agent(startingAt pid: Int32?, provider: AgentProvider) -> AgentIdentity? {
        var current = pid
        for _ in 0..<Self.maxDepth {
            guard let pid = current, pid > 1, let detail = inspector.detail(of: pid) else { return nil }
            if Self.isAgent(detail, provider: provider) { return AgentIdentity(pid: pid, startedAt: detail.startedAt) }
            current = detail.parentPid
        }
        return nil
    }

    func isAlive(_ agent: AgentIdentity) -> Bool {
        inspector.detail(of: agent.pid)?.startedAt == agent.startedAt
    }

    /// Matches the agent by kernel name, by argv[0] (native Claude execs a versioned binary such as
    /// ".../claude/versions/2.1.287", so its kernel name is the version), or by the npm package path.
    static func isAgent(_ detail: ProcessDetail, provider: AgentProvider) -> Bool {
        let name = detail.name.lowercased()
        let argv0 = (detail.command.split(separator: " ").first.map(String.init) ?? "") as NSString
        let program = argv0.lastPathComponent.lowercased()
        switch provider {
        case .claude: return name == "claude" || program == "claude" || detail.command.contains("@anthropic-ai/claude-code/")
        case .codex: return name == "codex" || program == "codex" || detail.command.contains("@openai/codex")
        }
    }
}
