import Foundation

enum AgentProvider: String, Codable, Sendable {
    case claude
    case codex
}

/// One line of JSON sent by tokencats-hook.py.
struct HookEnvelope: Decodable, Equatable, Sendable {
    let provider: AgentProvider
    let sessionId: String
    let event: String
    let cwd: String
    let tool: String?
    let toolSummary: String?
    let orcaTerminal: String?
    let ts: Double
    /// Parent of the hook process; the app walks up from it to find the agent process.
    let hookPpid: Int32?

    enum CodingKeys: String, CodingKey {
        case provider, event, cwd, tool, ts
        case sessionId = "session_id"
        case toolSummary = "tool_summary"
        case orcaTerminal = "orca_terminal"
        case hookPpid = "hook_ppid"
    }
}

/// The claude/codex process behind a session; start time guards against PID reuse.
struct AgentIdentity: Equatable, Sendable {
    let pid: Int32
    let startedAt: String
}

enum AgentState: String, Sendable {
    case idle, working, needsApproval, turnDone, error, unknown
}

struct AgentSession: Equatable, Identifiable, Sendable {
    var id: String { "\(provider.rawValue):\(sessionId)" }
    let provider: AgentProvider
    let sessionId: String
    var cwd: String
    var state: AgentState
    var orcaTerminal: String?
    var lastEventAt: Double
    var agent: AgentIdentity? = nil
    /// Orca tab title, fetched once; tells apart sessions in the same folder.
    var terminalTitle: String? = nil
    var branch: String? = nil
    /// Last tool the agent started and what it acted on (e.g. "Edit", "/path/File.swift").
    var currentTool: String? = nil
    var currentSummary: String? = nil
    /// Event time when `state` last changed.
    var stateSince: Double = 0
    /// The agent finished its turn and the user has not looked yet.
    var unseenDone: Bool = false

    var folderName: String { (cwd as NSString).lastPathComponent }
}

/// Counts shown at the top of the home: what is running and what needs the user.
struct SessionSummary: Equatable, Sendable {
    var working = 0
    var needsApproval = 0
    var unseenDone = 0
}

enum CharacterMood: Equatable, Sendable {
    case idle, working, needsApproval, done, error
}
