import Foundation

/// The agent session the app knew, saved so a restarted app can find it again.
struct SessionSnapshot: Codable, Equatable, Sendable {
    let provider: AgentProvider
    let sessionId: String
    let cwd: String
    let agentPid: Int32
    let agentStartedAt: String
    let orcaTerminal: String?
    let terminalTitle: String?
    let branch: String?
    /// Missing in files saved by older builds.
    let lastEventAt: Double?

    var id: String { "\(provider.rawValue):\(sessionId)" }

    init?(_ session: AgentSession) {
        guard let agent = session.agent else { return nil }
        provider = session.provider
        sessionId = session.sessionId
        cwd = session.cwd
        agentPid = agent.pid
        agentStartedAt = agent.startedAt
        orcaTerminal = session.orcaTerminal
        terminalTitle = session.terminalTitle
        branch = session.branch
        lastEventAt = session.lastEventAt
    }
}
