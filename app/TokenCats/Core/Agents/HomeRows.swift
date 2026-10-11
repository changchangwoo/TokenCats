import Foundation

enum HomeRow: Equatable, Identifiable {
    case session(AgentSession)
    case result(RecentResult)

    var id: String {
        switch self {
        case .session(let session): return session.id
        case .result(let result): return result.id
        }
    }
}

/// What the home shows: the session strip and the full list.
enum HomeRows {
    /// A calm session with no activity this long sleeps: grey in the strip.
    static let sleepAfter: Double = 24 * 3600

    static func isAsleep(_ session: AgentSession, now: Double) -> Bool {
        guard [.idle, .turnDone, .unknown].contains(session.state), !session.unseenDone else { return false }
        return now - session.lastEventAt > sleepAfter
    }

    /// Every live session plus unseen results of ended ones: urgent first, then working, calm, asleep; recent first within each.
    static func strip(sessions: [AgentSession], results: [RecentResult], now: Double) -> [HomeRow] {
        let live = Set(sessions.map(\.id))
        var ranked: [(rank: Int, time: Double, row: HomeRow)] = sessions.map { (rank($0, now: now), $0.lastEventAt, .session($0)) }
        for result in results where !result.seen && !live.contains(result.id) {
            ranked.append((2, result.endedAt.timeIntervalSince1970, .result(result)))
        }
        return ranked.sorted { ($0.rank, -$0.time, $0.row.id) < ($1.rank, -$1.time, $1.row.id) }.map(\.row)
    }

    private static func rank(_ session: AgentSession, now: Double) -> Int {
        switch session.state {
        case .needsApproval: return 0
        case .error: return 1
        case _ where session.unseenDone: return 2
        case .working: return 3
        case _ where isAsleep(session, now: now): return 5
        default: return 4
        }
    }
}
