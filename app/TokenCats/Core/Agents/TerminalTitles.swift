import Foundation

struct TerminalInfo: Equatable, Sendable {
    var title: String?
    var branch: String?
}

protocol TerminalTitleProvider: Sendable {
    /// Blocking; nil when the terminal is unknown or the CLI is unavailable.
    func info(for handle: String) -> TerminalInfo?
}

/// Reads an Orca terminal tab title via `orca terminal show --json`.
struct OrcaTerminalTitles: TerminalTitleProvider {
    static let cliCandidates = ["/usr/local/bin/orca", "/opt/homebrew/bin/orca"]

    var runner: any CommandRunner = SystemCommandRunner()

    func info(for handle: String) -> TerminalInfo? {
        guard let cli = Self.cliCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        let result = runner.run(cli, ["terminal", "show", "--terminal", handle, "--json"])
        guard result.status == 0 else { return nil }
        return Self.parseInfo(Data(result.stdout.utf8))
    }

    static func parseInfo(_ data: Data) -> TerminalInfo? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["ok"] as? Bool == true,
              let terminal = (root["result"] as? [String: Any])?["terminal"] as? [String: Any] else { return nil }
        let branch = (terminal["branch"] as? String).map { $0.hasPrefix("refs/heads/") ? String($0.dropFirst(11)) : $0 }
        return TerminalInfo(title: parseTitle(data), branch: branch)
    }

    /// Orca prefixes titles with an activity glyph ("◑ "); keep the text from the first letter or digit.
    static func parseTitle(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["ok"] as? Bool == true,
              let terminal = (root["result"] as? [String: Any])?["terminal"] as? [String: Any],
              let raw = terminal["title"] as? String else { return nil }
        let title = String(raw.drop { !($0.isLetter || $0.isNumber) }).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
}
