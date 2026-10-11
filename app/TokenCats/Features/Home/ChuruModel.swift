import SwiftUI

/// Runs the churu tracker off the main thread and publishes its latest snapshot.
/// Store purchases run on the same queue so they always see the balance the tracker just computed.
@MainActor
final class ChuruModel: ObservableObject {
    static let shared = ChuruModel()

    @Published private(set) var snapshot: ChuruSnapshot?

    /// The wall calendar: this month's churu, or this month with every day blank until the first count finishes,

    /// so the room never shows a bare sheet.

    var wallCalendar: ChuruMonthCalendar {

        snapshot?.calendar ?? ChuruCalendar.empty(containing: Date(), calendar: .current)

    }
    let tracker = ChuruTracker.live
    private let queue = DispatchQueue(label: "tokencats.churu", qos: .utility)
    private var refreshing = false

    /// The first refresh after launch reads every log modified today and can take a few seconds.
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let tracker = tracker
        snapshot = await perform { tracker.refresh() }
    }

    func perform<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }

    func publish(_ snapshot: ChuruSnapshot) { self.snapshot = snapshot }
}
