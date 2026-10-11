import Foundation
import Testing
@testable import TokenCatsCore

struct NotchSlotsTests {
    func session(_ id: String, _ provider: AgentProvider, _ state: AgentState, at ts: Double = 1) -> AgentSession {
        AgentSession(provider: provider, sessionId: id, cwd: "/p/\(id)", state: state, orcaTerminal: nil, lastEventAt: ts)
    }

    @Test func noSessionsShowsOneIdleDefaultSlot() {
        let layout = NotchSlots.layout(for: [], limit: 4)
        #expect(layout.slots == [NotchSlot(id: "default", provider: nil, mood: .idle)])
        #expect(layout.overflow == 0)
    }

    @Test func eachSessionGetsItsOwnSlotWithItsOwnMood() {
        let layout = NotchSlots.layout(for: [
            session("a", .claude, .needsApproval),
            session("b", .codex, .working),
            session("c", .claude, .turnDone),
        ], limit: 4)
        #expect(layout.slots.map(\.id) == ["claude:a", "codex:b", "claude:c"])
        #expect(layout.slots.map(\.mood) == [.needsApproval, .working, .done])
        #expect(layout.slots.map(\.provider) == [.claude, .codex, .claude])
    }

    @Test func statesMapToMoods() {
        #expect(NotchSlots.mood(for: .idle) == .idle)
        #expect(NotchSlots.mood(for: .unknown) == .idle)
        #expect(NotchSlots.mood(for: .error) == .error)
    }

    @Test func overflowBeyondLimitIsCounted() {
        let sessions = (0..<6).map { session("s\($0)", .claude, .working) }
        let layout = NotchSlots.layout(for: sessions, limit: 4)
        #expect(layout.slots.count == 4)
        #expect(layout.overflow == 2)
    }

    @Test func slotsCarryUnseenCompletion() {
        var done = session("a", .claude, .turnDone)
        done.unseenDone = true
        let layout = NotchSlots.layout(for: [done, session("b", .codex, .turnDone)], limit: 4)
        #expect(layout.slots.map(\.unseen) == [true, false])
    }
}

