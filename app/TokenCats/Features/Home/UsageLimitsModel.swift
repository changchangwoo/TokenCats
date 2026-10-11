import SwiftUI

/// Reads the limit sources off the main thread; refreshed only while Home is on screen.
@MainActor
final class UsageLimitsModel: ObservableObject {
    static let shared = UsageLimitsModel()

    @Published private(set) var claude: LimitReading?
    @Published private(set) var codex: LimitReading?
    @Published private(set) var claudeConnected = false
    private let queue = DispatchQueue(label: "tokencats.limits", qos: .utility)

    /// Adding a provider adds one source here; the ledger layout stays unchanged.
    var sources: [UsageSource] {
        [source(id: "claude", name: "Claude", reading: claude,
                state: !claudeConnected ? .needsConnection : (claude == nil ? .waiting : .ready)),
         source(id: "codex", name: "Codex", reading: codex,
                state: codex == nil ? .waiting : .ready)]
    }

    private func source(id: String, name: String, reading: LimitReading?, state: UsageSource.State) -> UsageSource {
        UsageSource(id: id, name: name, state: state,
                    metrics: reading?.windows.map { window in
                        UsageMetric(kind: window.kind,
                                    value: "\(Int(window.usedPercent.rounded()))%",
                                    fraction: window.usedPercent / 100, resetsAt: window.resetsAt)
                    } ?? [], observedAt: reading?.observedAt)
    }

    func refresh() async {
        let result = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: (StatusLineIntegration.claude.isInstalled(),
                                                ClaudeLimitSnapshot.read(url: AppPaths.claudeLimitsURL),
                                                CodexLimitReader().latest()))
            }
        }
        claudeConnected = result.0
        claude = result.1
        codex = result.2
    }
}
