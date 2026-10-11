import Combine
import Foundation

/// Live agent sessions and their recent results, fed by the hook socket.
@MainActor
final class AgentHub: ObservableObject {
    static let shared = AgentHub(source: SocketServer.shared)

    @Published private(set) var sessions: [AgentSession] = []
    /// Sessions that want the user; the closed notch shows only these.
    @Published private(set) var waitingSessions: [AgentSession] = []
    @Published private(set) var mood: CharacterMood = .idle
    @Published private(set) var summary = SessionSummary()
    @Published private(set) var results: [RecentResult] = []

    private let storage: DataFiles
    private let now: () -> Date
    private var recent: RecentResults
    private var snapshots: [SessionSnapshot] = []
    /// Snapshots are only written after recovery told which sessions still live.
    private var restoreFinished = false

    private let source: any AgentHookEventSource
    private let locator: AgentLocator
    private let titles: any TerminalTitleProvider
    private var requestedTitles: Set<String> = []
    private var book = SessionBook()
    private var staleTimer: Timer?

    init(
        source: any AgentHookEventSource,
        locator: AgentLocator = AgentLocator(inspector: SystemProcessInspector()),
        titles: any TerminalTitleProvider = OrcaTerminalTitles(),
        storage: DataFiles = .live,
        now: @escaping () -> Date = Date.init
    ) {
        self.source = source
        self.locator = locator
        self.titles = titles
        self.storage = storage
        self.now = now
        var recent = storage.results.load() ?? RecentResults()
        recent.prune(now: now())
        self.recent = recent
        self.snapshots = storage.sessions.load() ?? []
        self.results = recent.items
    }

    /// Snapshots saved by the previous run; read by the launch-time recovery.
    var savedSnapshots: [SessionSnapshot] { snapshots }

    /// Recovery finished: adds the sessions it found, then starts saving snapshots.
    func finishRestore(_ recovered: [RecoveredSession] = []) {
        let nowSeconds = now().timeIntervalSince1970
        for session in recovered {
            book.restore(session, now: nowSeconds)
            if let handle = session.orcaTerminal, session.terminalTitle == nil { requestTitle(handle) }
        }
        restoreFinished = true
        publish()
    }

    /// Launch-time recovery off the main thread.
    func restoreLive() {
        let snapshots = snapshots
        Task.detached { [weak self] in
            let recovered = SessionRecovery.live.recover(snapshots: snapshots)
            await self?.finishRestore(recovered)
        }
    }

    /// The user confirmed a result in its card.
    func markSeen(_ id: String) {
        guard recent.markSeen(id) else { return }
        storage.results.save(recent)
        publish()
    }

    /// Only a successful jump counts as looking at the result.
    func finishJump(_ id: String, succeeded: Bool) {
        if succeeded { markSeen(id) }
    }

    func start() {
        source.start { [weak self] envelope in
            self?.handle(envelope)
        }
    }

    func stop() {
        source.stop()
        staleTimer?.invalidate()
        staleTimer = nil
    }

    /// Removes sessions whose claude/codex process has exited (Ctrl+C, closed terminal, crash).
    func pruneDeadSessions() {
        book.removeDead(isAlive: locator.isAlive)
        publish()
    }

    /// Runs on a socket client thread. Observation only: never replies.
    nonisolated private func handle(_ envelope: HookEnvelope) -> Data? {
        // Resolve now, while the hook's parent chain is still alive.
        let agent = locator.agent(startingAt: envelope.hookPpid, provider: envelope.provider)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.apply(envelope, agent: agent) }
        }
        return nil
    }

    private func apply(_ envelope: HookEnvelope, agent: AgentIdentity?) {
        book.apply(envelope, agent: agent)
        let id = "\(envelope.provider.rawValue):\(envelope.sessionId)"
        if let session = book.sessions[id] {
            switch envelope.event {
            case "Stop": recordResult(session, .success)
            // A failed tool mid-turn is only a state; the turn has not ended.
            case "StopFailure": recordResult(session, .error)
            case "UserPromptSubmit": if recent.markSeen(id) { storage.results.save(recent) }
            default: break
            }
        }
        publish()
        if let handle = envelope.orcaTerminal { requestTitle(handle) }
    }

    private func recordResult(_ session: AgentSession, _ outcome: ResultOutcome) {
        recent.record(session, outcome: outcome, at: now())
        storage.results.save(recent)
    }

    /// Looks up the Orca tab title once per terminal, off the main thread.
    private func requestTitle(_ handle: String) {
        guard requestedTitles.insert(handle).inserted else { return }
        let titles = titles
        Task.detached { [weak self] in
            guard let info = titles.info(for: handle) else { return }
            await self?.applyTerminalInfo(info, forTerminal: handle)
        }
    }

    private func applyTerminalInfo(_ info: TerminalInfo, forTerminal handle: String) {
        book.setTerminalInfo(info, forTerminal: handle)
        publish()
    }

    private func publish() {
        book.syncUnseen(recent.unseenIds)
        let ordered = book.orderedSessions
        if ordered != sessions { sessions = ordered }
        // Also re-run by the 10s liveness timer, so sessions fall asleep without new events
        let waiting = HomeRows.waiting(sessions: ordered)
        if waiting != waitingSessions { waitingSessions = waiting }
        if book.mood != mood { mood = book.mood }
        if book.summary != summary { summary = book.summary }
        if recent.items != results { results = recent.items }
        saveSnapshots(ordered)
        if sessions.isEmpty {
            staleTimer?.invalidate()
            staleTimer = nil
        } else if staleTimer == nil {
            // Only runs while sessions exist; each tick is a few libproc calls.
            let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.book.markStale(now: Date().timeIntervalSince1970)
                    self?.pruneDeadSessions()
                }
            }
            timer.tolerance = 5
            staleTimer = timer
        }
    }

    private func saveSnapshots(_ sessions: [AgentSession]) {
        guard restoreFinished else { return }
        let current = sessions.compactMap(SessionSnapshot.init)
        if current != snapshots {
            snapshots = current
            storage.sessions.save(current)
        }
    }
}
