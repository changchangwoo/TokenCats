import SwiftUI

/// Reads the limit sources off the main thread; refreshed only while Home is on screen.
@MainActor
final class UsageLimitsModel: ObservableObject {
    static let shared = UsageLimitsModel()

    @Published private(set) var claude: LimitReading?
    @Published private(set) var codex: LimitReading?
    @Published private(set) var fablePercent: Double?
    @Published var selectedProviderID: String? = nil
    @Published private(set) var claudeConnected = false
    private let queue = DispatchQueue(label: "tokencats.limits", qos: .utility)
    private var fableRefreshedAt: Date?
    private var refreshingFable = false

    /// Adding a provider adds one source here; the ledger layout stays unchanged.
    var sources: [UsageSource] {
        [source(id: "claude", name: "Claude", reading: claude,
                state: !claudeConnected ? .needsConnection : (claude == nil ? .waiting : .ready),
                fablePercent: fablePercent),
         source(id: "codex", name: "Codex", reading: codex,
                state: codex == nil ? .waiting : .ready)]
    }

    func visibleLimitRows(for display: HomeDisplaySettings) -> Int {
        let visible = sources.filter { !display.hiddenProviderIDs.contains($0.id) }
        guard let selected = visible.first(where: { $0.id == selectedProviderID }) ?? visible.first,
              !selected.metrics.isEmpty else { return 2 }
        return min(max(selected.metrics.count, 1), 3)
    }

    private func source(id: String, name: String, reading: LimitReading?, state: UsageSource.State,
                        fablePercent: Double? = nil) -> UsageSource {
        var metrics = reading?.windows.map { window in
            UsageMetric(kind: window.kind,
                        value: "\(Int(window.usedPercent.rounded()))%",
                        fraction: window.usedPercent / 100, resetsAt: window.resetsAt)
        } ?? []
        if let fablePercent {
            metrics.append(UsageMetric(kind: .fableWeekly, value: "\(Int(fablePercent.rounded()))%",
                                       fraction: fablePercent / 100, resetsAt: nil))
        }
        return UsageSource(id: id, name: name, state: state,
                           metrics: metrics, observedAt: reading?.observedAt)
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

    /// A separate Claude CLI read is needed for Fable; the status-line payload omits that model-scoped window.
    func refreshFableIfNeeded() async {
        guard !refreshingFable,
              fableRefreshedAt.map({ Date().timeIntervalSince($0) >= 900 }) ?? true else { return }
        refreshingFable = true
        fableRefreshedAt = Date()
        defer { refreshingFable = false }
        let percent = await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: FableUsageReader().read()) }
        }
        fablePercent = percent
    }
}
