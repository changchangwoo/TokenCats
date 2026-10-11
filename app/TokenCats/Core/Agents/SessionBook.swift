import Foundation

/// Pure state rules: hook events in, per-session state out. No I/O.
struct SessionBook {
    static let dropAfter: Double = 6 * 3600

    private(set) var sessions: [String: AgentSession] = [:]

    mutating func apply(_ e: HookEnvelope, agent: AgentIdentity? = nil) {
        let key = "\(e.provider.rawValue):\(e.sessionId)"
        if let existing = sessions[key], e.ts < existing.lastEventAt { return }

        if e.event == "SessionEnd" {
            sessions[key] = nil
            return
        }

        var session = sessions[key] ?? AgentSession(
            provider: e.provider, sessionId: e.sessionId, cwd: e.cwd, state: .idle,
            orcaTerminal: e.orcaTerminal, lastEventAt: e.ts, stateSince: e.ts)
        let previousState = session.state
        if !e.cwd.isEmpty { session.cwd = e.cwd }
        if let terminal = e.orcaTerminal { session.orcaTerminal = terminal }
        if session.agent == nil { session.agent = agent }
        session.lastEventAt = e.ts

        switch e.event {
        case "SessionStart":
            session.state = .idle
        case "UserPromptSubmit":
            session.state = .working
            session.unseenDone = false
            session.currentTool = nil
            session.currentSummary = nil
        case "PreToolUse":
            session.state = .working
            session.currentTool = e.tool
            session.currentSummary = e.toolSummary
        case "PostToolUse":
            session.state = .working
        case "PermissionRequest":
            // The agent asks in its own terminal; the notch only shows that it waits.
            session.state = .needsApproval
            session.currentTool = e.tool ?? session.currentTool
            session.currentSummary = e.toolSummary ?? session.currentSummary
        case "Stop":
            session.state = .turnDone
            session.unseenDone = true
        case "StopFailure", "PostToolUseFailure":
            session.state = .error
        default:
            break
        }

        if session.state != previousState { session.stateSince = e.ts }
        sessions[key] = session
    }

    /// Adds a session found by recovery. A session already known from live events is left as is.
    mutating func restore(_ r: RecoveredSession, now: Double) {
        guard sessions[r.id] == nil else { return }
        var session = AgentSession(
            provider: r.provider, sessionId: r.sessionId, cwd: r.cwd, state: r.state,
            orcaTerminal: r.orcaTerminal, lastEventAt: r.lastActivity ?? now, agent: r.agent,
            stateSince: r.lastActivity ?? now)
        session.terminalTitle = r.terminalTitle
        session.branch = r.branch
        sessions[r.id] = session
    }

    /// The unseen mark is owned by `RecentResults`; live sessions mirror it.
    mutating func syncUnseen(_ ids: Set<String>) {
        for (key, var session) in sessions where session.unseenDone != ids.contains(key) {
            session.unseenDone = ids.contains(key)
            sessions[key] = session
        }
    }

    var summary: SessionSummary {
        var summary = SessionSummary()
        for session in sessions.values {
            if session.state == .working { summary.working += 1 }
            if session.state == .needsApproval { summary.needsApproval += 1 }
            if session.unseenDone { summary.unseenDone += 1 }
        }
        return summary
    }

    /// Drops sessions whose agent process is gone. Sessions with no known agent are left to `markStale`.
    mutating func removeDead(isAlive: (AgentIdentity) -> Bool) {
        for (key, session) in sessions {
            guard let agent = session.agent, !isAlive(agent) else { continue }
            sessions[key] = nil
        }
    }

    mutating func setTerminalInfo(_ info: TerminalInfo, forTerminal handle: String) {
        for (key, var session) in sessions where session.orcaTerminal == handle {
            session.terminalTitle = info.title ?? session.terminalTitle
            session.branch = info.branch ?? session.branch
            sessions[key] = session
        }
    }

    /// Sessions whose agent process is unknown cannot be liveness-checked; drop them after long silence.
    /// Tracked agents are never changed for silence (a long build sends no events).
    mutating func markStale(now: Double) {
        for (key, session) in sessions where session.agent == nil && now - session.lastEventAt > Self.dropAfter {
            sessions[key] = nil
        }
    }

    var orderedSessions: [AgentSession] {
        sessions.values.sorted {
            let (l, r) = (Self.rank($0), Self.rank($1))
            return l != r ? l < r : $0.lastEventAt > $1.lastEventAt
        }
    }

    var mood: CharacterMood {
        let states = Set(sessions.values.map(\.state))
        if states.contains(.needsApproval) { return .needsApproval }
        if states.contains(.error) { return .error }
        if states.contains(.working) { return .working }
        if states.contains(.turnDone) { return .done }
        return .idle
    }

    /// "My turn" first: approvals, errors and unseen completions, then running work, then the rest.
    private static func rank(_ session: AgentSession) -> Int {
        switch session.state {
        case .needsApproval: return 0
        case .error: return 1
        case .turnDone where session.unseenDone: return 2
        case .working: return 3
        case .turnDone: return 4
        case .idle: return 5
        case .unknown: return 6
        }
    }
}
