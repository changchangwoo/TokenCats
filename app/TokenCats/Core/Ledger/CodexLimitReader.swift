import Foundation

/// The latest `rate_limits` Codex wrote to its session logs (`token_count` events).
/// Reads only the tail of the few newest files, so it is cheap enough for a 30-second refresh.
struct CodexLimitReader {
    static let tailBytes = 256 * 1024
    static let maxFiles = 5

    let sessionsRoot: URL

    init(sessionsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions", isDirectory: true)) {
        self.sessionsRoot = sessionsRoot
    }

    func latest() -> LimitReading? {
        for file in recentFiles() {
            if let reading = Self.lastReading(in: tail(of: file)) { return reading }
        }
        return nil
    }

    /// ≤ 300 minutes is the five-hour window, ≥ a week the weekly one, anything else whole hours.
    static func windowKind(minutes: Int) -> LimitWindowKind {
        minutes <= 300 ? .fiveHour : minutes >= 10_080 ? .weekly : .hours(minutes / 60)
    }

    /// Newest `.jsonl` files from the two latest `YYYY/MM/DD` folders.
    private func recentFiles() -> [URL] {
        let years = Self.folders(in: sessionsRoot)
        let months = years.flatMap(Self.folders)
        let days = months.flatMap(Self.folders).sorted { $0.path > $1.path }.prefix(2)
        let files = days.flatMap { day in
            ((try? FileManager.default.contentsOfDirectory(at: day, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
                .filter { $0.pathExtension == "jsonl" }
        }
        return Array(files.sorted { Self.modified($0) > Self.modified($1) }.prefix(Self.maxFiles))
    }

    private static func folders(in url: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles])) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func tail(of url: URL) -> Data {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(Self.tailBytes) ? size - UInt64(Self.tailBytes) : 0
        try? handle.seek(toOffset: start)
        var data = (try? handle.readToEnd()) ?? Data()
        // A tail that starts mid-line drops that partial line.
        if start > 0, let newline = data.firstIndex(of: 0x0A) { data = data[(newline + 1)...] }
        return Data(data)
    }

    static func lastReading(in data: Data) -> LimitReading? {
        let marker = Data("rate_limits".utf8)
        for line in data.split(separator: 0x0A).reversed() where line.range(of: marker) != nil {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let limits = payload["rate_limits"] as? [String: Any],
                  let stamp = object["timestamp"] as? String,
                  let observedAt = TokenLogParser.parseTimestamp(stamp)
            else { continue }
            let windows = ["primary", "secondary"].compactMap { key -> LimitWindow? in
                guard let window = limits[key] as? [String: Any],
                      let used = (window["used_percent"] as? NSNumber)?.doubleValue,
                      let minutes = (window["window_minutes"] as? NSNumber)?.intValue,
                      let resets = (window["resets_at"] as? NSNumber)?.doubleValue
                else { return nil }
                return LimitWindow(kind: windowKind(minutes: minutes), usedPercent: used,
                                   resetsAt: Date(timeIntervalSince1970: resets))
            }
            if !windows.isEmpty { return LimitReading(provider: .codex, windows: windows, observedAt: observedAt) }
        }
        return nil
    }
}
