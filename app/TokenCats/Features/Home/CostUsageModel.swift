import SwiftUI

/// API-equivalent estimates from local logs, refreshed only while Home or Statistics is visible.
@MainActor
final class CostUsageModel: ObservableObject {
    static let shared = CostUsageModel()

    @Published private(set) var snapshot: CostSnapshot?
    private let tracker = CostTracker.live
    private let queue = DispatchQueue(label: "tokencats.cost", qos: .utility)
    private var refreshing = false

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let tracker = tracker
        snapshot = await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: tracker.refresh()) }
        }
    }
}
