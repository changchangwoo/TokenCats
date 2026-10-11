import Foundation

enum AppPaths {
    static var supportDirectory: URL { supportDirectory(environment: ProcessInfo.processInfo.environment) }

    /// In Debug builds `NC_SUPPORT_DIR` points a run (snapshots, tests) at a frozen copy of the data. Release
    /// builds ignore it: the hook script's socket path is fixed, so an override there would split the two.
    static func supportDirectory(environment: [String: String]) -> URL {
        #if DEBUG
        if let override = environment["NC_SUPPORT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        #endif
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TokenCats", isDirectory: true)
    }

    static var socketPath: String {
        supportDirectory.appendingPathComponent("companion.sock").path
    }

    static var hookScriptURL: URL {
        supportDirectory.appendingPathComponent("tokencats-hook.py")
    }

    static var statusLineScriptURL: URL {
        supportDirectory.appendingPathComponent("tokencats-statusline.py")
    }

    /// The user's own `statusLine`, kept while ours wraps it.
    static var statusLineOriginalURL: URL {
        supportDirectory.appendingPathComponent("statusline-original.json")
    }

    /// Claude's `rate_limits`, written by the status-line wrapper.
    static var claudeLimitsURL: URL {
        supportDirectory.appendingPathComponent("claude-limits.json")
    }
}
