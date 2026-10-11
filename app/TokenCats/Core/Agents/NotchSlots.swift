import Foundation

/// One character in the closed notch. `provider == nil` is the default idle character shown when no session runs.
struct NotchSlot: Equatable, Identifiable, Sendable {
    let id: String
    let provider: AgentProvider?
    let mood: CharacterMood
    var unseen = false
}

enum NotchSlots {
    struct Layout: Equatable {
        let slots: [NotchSlot]
        /// Sessions not shown because of the limit.
        let overflow: Int
    }

    /// Sessions are expected in display priority order (`SessionBook.orderedSessions`).
    static func layout(for sessions: [AgentSession], limit: Int) -> Layout {
        guard !sessions.isEmpty else {
            return Layout(slots: [NotchSlot(id: "default", provider: nil, mood: .idle)], overflow: 0)
        }
        let shown = sessions.prefix(limit).map {
            NotchSlot(id: $0.id, provider: $0.provider, mood: mood(for: $0.state), unseen: $0.unseenDone)
        }
        return Layout(slots: shown, overflow: max(0, sessions.count - limit))
    }

    static func mood(for state: AgentState) -> CharacterMood {
        switch state {
        case .needsApproval: return .needsApproval
        case .error: return .error
        case .working: return .working
        case .turnDone: return .done
        case .idle, .unknown: return .idle
        }
    }
}
