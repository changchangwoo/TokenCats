import SwiftUI

/// Picks one cat to blink every few seconds. Nothing redraws in between, so a closed notch costs next to nothing.
@MainActor
final class ClosedNotchBlinks: ObservableObject {
    @Published private(set) var blinking: String?
    private var task: Task<Void, Never>?

    func start(cats: [String]) {
        task?.cancel()
        blinking = nil
        guard !cats.isEmpty else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 3.5...8)))
                guard !Task.isCancelled, let cat = cats.randomElement() else { return }
                self?.blinking = cat
                try? await Task.sleep(for: .milliseconds(160))
                self?.blinking = nil
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        blinking = nil
    }
}
