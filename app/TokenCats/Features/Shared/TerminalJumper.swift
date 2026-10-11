import AppKit
import os

private let jumpLog = Logger(subsystem: "TokenCats", category: "jump")

enum TerminalJumper {
    static let orcaBundleId = "com.stablyai.orca"
    static let cliCandidates = ["/usr/local/bin/orca", "/opt/homebrew/bin/orca"]

    /// Selects the session's Orca terminal tab and brings Orca forward. False when the tab could not be selected.
    static func jump(to handle: String?) async -> Bool {
        let switched = await Task.detached { () -> Bool in
            guard let handle,
                  let cli = cliCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                return false
            }
            let result = SystemCommandRunner().run(cli, ["terminal", "switch", "--terminal", handle, "--json"])
            guard result.status == 0,
                  let object = try? JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any] else {
                return false
            }
            return object["ok"] as? Bool == true
        }.value
        NSRunningApplication.runningApplications(withBundleIdentifier: orcaBundleId).first?.activate()
        jumpLog.notice("jump handle=\(handle ?? "nil", privacy: .public) switched=\(switched, privacy: .public)")
        return switched
    }
}
