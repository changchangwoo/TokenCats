import Foundation

/// Claude's status-line JSON omits model-scoped weekly limits. The official `/usage` command exposes Fable as text.
enum FableUsageParser {
    static func percent(from data: Data) -> Double? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["is_error"] as? Bool == false,
              let result = object["result"] as? String else { return nil }
        let prefix = "Current week (Fable):"
        guard let line = result.split(separator: "\n").first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let remainder = line.dropFirst(prefix.count)
        guard let marker = remainder.range(of: "% used"),
              let percent = Double(remainder[..<marker.lowerBound].trimmingCharacters(in: .whitespaces)),
              (0...100).contains(percent) else { return nil }
        return percent
    }
}

/// Best-effort, zero-token Claude CLI read. It never stores the command's full usage report.
struct FableUsageReader: Sendable {
    static let timeout: TimeInterval = 15

    func read() -> Double? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [home.appendingPathComponent(".local/bin/claude").path,
                          home.appendingPathComponent(".zeude/bin/claude").path,
                          "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        guard let executable = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-p", "/usage", "--output-format", "json"]
        process.currentDirectoryURL = home
        var environment = ProcessInfo.processInfo.environment
        // The command's own hooks must not create a visible TokenCats session or result.
        environment["TOKENCATS_SOCKET"] = "/tmp/tokencats-usage-\(UUID().uuidString).sock"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }
        guard finished.wait(timeout: .now() + Self.timeout) == .success else {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        return FableUsageParser.percent(from: output.fileHandleForReading.readDataToEndOfFile())
    }
}
