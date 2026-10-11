import Foundation

/// `claude-limits.json`, written by the status-line wrapper from Claude Code's `rate_limits`.
/// `{"updated_at": epoch, "five_hour"?: {"used_percentage", "resets_at"}, "seven_day"?: {...}}`
enum ClaudeLimitSnapshot {
    static func reading(from data: Data) -> LimitReading? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let updated = number(object["updated_at"]) else { return nil }
        let windows = [("five_hour", LimitWindowKind.fiveHour), ("seven_day", .weekly)].compactMap { key, kind -> LimitWindow? in
            guard let window = object[key] as? [String: Any],
                  let used = number(window["used_percentage"]), let resets = number(window["resets_at"])
            else { return nil }
            return LimitWindow(kind: kind, usedPercent: used, resetsAt: Date(timeIntervalSince1970: resets))
        }
        return LimitReading(provider: .claude, windows: windows, observedAt: Date(timeIntervalSince1970: updated))
    }

    static func read(url: URL) -> LimitReading? {
        (try? Data(contentsOf: url)).flatMap(reading)
    }

    private static func number(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }
}
