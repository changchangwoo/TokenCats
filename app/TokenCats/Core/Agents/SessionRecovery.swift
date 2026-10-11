import Foundation

struct RecoveredSession: Equatable, Sendable {
    let provider: AgentProvider
    let sessionId: String
    let cwd: String
    let agent: AgentIdentity
    let orcaTerminal: String?
    let terminalTitle: String?
    let branch: String?
    let state: AgentState
    /// Last sign of life before the app started (event or file write); nil when unknown.
    var lastActivity: Double? = nil

    var id: String { "\(provider.rawValue):\(sessionId)" }
}

/// Finds agent sessions that are running while the app starts.
/// Stage 1: sessions the app saved, if their exact process still lives. Stage 2: other live agent processes,
/// identified only from Claude's per-process session file or the *name* of Codex's open rollout file.
struct SessionRecovery {
    let inspector: any ProcessInspector
    let claudeSessionsDirectory: URL
    /// Modification time of a file, seconds since 1970; injectable for tests.
    var modifiedAt: @Sendable (String) -> Double? = SessionRecovery.fileModifiedAt

    static var live: SessionRecovery {
        SessionRecovery(
            inspector: SystemProcessInspector(),
            claudeSessionsDirectory: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/sessions"))
    }

    func recover(snapshots: [SessionSnapshot]) -> [RecoveredSession] {
        let locator = AgentLocator(inspector: inspector)
        var found: [String: RecoveredSession] = [:]
        var claimedPids: Set<Int32> = []

        for s in snapshots {
            let agent = AgentIdentity(pid: s.agentPid, startedAt: s.agentStartedAt)
            guard locator.isAlive(agent) else { continue }
            found[s.id] = RecoveredSession(
                provider: s.provider, sessionId: s.sessionId, cwd: s.cwd, agent: agent, orcaTerminal: s.orcaTerminal,
                terminalTitle: s.terminalTitle, branch: s.branch, state: .unknown,
                lastActivity: latest(s.lastEventAt, fileActivity(provider: s.provider, pid: s.agentPid)))
            claimedPids.insert(s.agentPid)
        }

        for pid in inspector.allPids() where !claimedPids.contains(pid) {
            guard let detail = inspector.detail(of: pid) else { continue }
            let agent = AgentIdentity(pid: pid, startedAt: detail.startedAt)
            let terminal = inspector.environment(of: pid)["ORCA_TERMINAL_HANDLE"]
            if AgentLocator.isAgent(detail, provider: .claude), let file = claudeFile(pid) {
                let r = RecoveredSession(
                    provider: .claude, sessionId: file.sessionId, cwd: file.cwd, agent: agent, orcaTerminal: terminal,
                    terminalTitle: nil, branch: nil, state: file.state,
                    lastActivity: fileActivity(provider: .claude, pid: pid))
                if found[r.id] == nil { found[r.id] = r }
            } else if AgentLocator.isAgent(detail, provider: .codex), let rollout = codexRollout(pid),
                      let id = Self.codexSessionId(fromPath: rollout) {
                let r = RecoveredSession(
                    provider: .codex, sessionId: id, cwd: detail.cwd ?? "", agent: agent, orcaTerminal: terminal,
                    terminalTitle: nil, branch: nil, state: .unknown, lastActivity: modifiedAt(rollout))
                if found[r.id] == nil { found[r.id] = r }
            }
        }
        return found.values.sorted { $0.id < $1.id }
    }

    /// Claude rewrites its per-process file on each status change; Codex appends to its rollout file.
    private func fileActivity(provider: AgentProvider, pid: Int32) -> Double? {
        switch provider {
        case .claude: return modifiedAt(claudeSessionsDirectory.appendingPathComponent("\(pid).json").path)
        case .codex: return codexRollout(pid).flatMap(modifiedAt)
        }
    }

    private func codexRollout(_ pid: Int32) -> String? {
        inspector.openFilePaths(of: pid).first { Self.codexSessionId(fromPath: $0) != nil }
    }

    private func latest(_ a: Double?, _ b: Double?) -> Double? {
        [a, b].compactMap { $0 }.max()
    }

    static func fileModifiedAt(_ path: String) -> Double? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)?.timeIntervalSince1970
    }

    /// "…/.codex/sessions/…/rollout-<timestamp>-<uuid>.jsonl" → uuid.
    static func codexSessionId(fromPath path: String) -> String? {
        guard path.contains("/.codex/sessions/") else { return nil }
        let name = (path as NSString).lastPathComponent
        guard name.hasPrefix("rollout-"), name.hasSuffix(".jsonl") else { return nil }
        let stem = name.dropLast(".jsonl".count)
        guard stem.count >= 36 else { return nil }
        let id = String(stem.suffix(36))
        return UUID(uuidString: id) == nil ? nil : id
    }

    private struct ClaudeFile: Decodable {
        let sessionId: String
        let cwd: String
        let status: String?

        var state: AgentState {
            switch status {
            case "busy": return .working
            case "idle": return .idle
            default: return .unknown
            }
        }
    }

    /// Claude's internal per-process file. Unknown shape → nil, never a guess.
    private func claudeFile(_ pid: Int32) -> ClaudeFile? {
        let url = claudeSessionsDirectory.appendingPathComponent("\(pid).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ClaudeFile.self, from: data)
    }
}
