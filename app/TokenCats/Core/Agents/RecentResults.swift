import Foundation

enum ResultOutcome: String, Codable, Sendable {
    case success, error
}

/// How a turn ended. No prompt, no command: only what the list needs to find and reopen the session.
struct RecentResult: Codable, Equatable, Identifiable, Sendable {
    let provider: AgentProvider
    let sessionId: String
    var title: String
    var folder: String
    var orcaTerminal: String?
    var endedAt: Date
    var outcome: ResultOutcome
    var seen: Bool

    var id: String { "\(provider.rawValue):\(sessionId)" }
}

/// Latest result per session, newest first. Owns the "finished but not looked at" mark.
struct RecentResults: Codable, Equatable {
    static let maxCount = 20
    static let maxAge: TimeInterval = 7 * 86400

    var items: [RecentResult] = []

    var unseenIds: Set<String> { Set(items.filter { !$0.seen }.map(\.id)) }

    mutating func record(_ session: AgentSession, outcome: ResultOutcome, at date: Date) {
        items.removeAll { $0.id == session.id }
        let result = RecentResult(
            provider: session.provider, sessionId: session.sessionId,
            title: session.terminalTitle ?? session.folderName, folder: session.folderName,
            orcaTerminal: session.orcaTerminal, endedAt: date, outcome: outcome, seen: false)
        items.insert(result, at: 0)
        if items.count > Self.maxCount { items.removeLast(items.count - Self.maxCount) }
    }

    @discardableResult
    mutating func markSeen(_ id: String) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].seen else { return false }
        items[index].seen = true
        return true
    }

    mutating func prune(now: Date) {
        items.removeAll { now.timeIntervalSince($0.endedAt) > Self.maxAge }
    }
}
