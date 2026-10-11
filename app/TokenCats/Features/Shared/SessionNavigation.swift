import SwiftUI

/// Brings the session's Orca tab forward. Only a successful jump marks its result as seen.
@MainActor
func jump(to id: String, terminal: String?, notice: Binding<LocalizedStringResource?>) {
    Task {
        let succeeded = await TerminalJumper.jump(to: terminal)
        AgentHub.shared.finishJump(id, succeeded: succeeded)
        if !succeeded { notice.wrappedValue = terminal == nil ? "This session has no Orca tab" : "Could not find the terminal tab" }
    }
}
