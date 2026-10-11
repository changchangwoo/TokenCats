import SwiftUI

/// A short message under a screen that fades after three seconds. The message stays a `LocalizedStringResource`
/// until it is drawn, so a language change while it shows changes it too.
@MainActor
final class Notice: ObservableObject {
    @Published private(set) var message: LocalizedStringResource?
    private var shown = UUID()

    func show(_ text: LocalizedStringResource) {
        let this = UUID()
        shown = this
        withAnimation(.smooth) { message = text }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.smooth) { if shown == this { message = nil } }
        }
    }
}
