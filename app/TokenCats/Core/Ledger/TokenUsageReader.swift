import Foundation

/// Agent CLI whose local logs are read for token usage.
enum TokenProvider: String, Codable, CaseIterable, Sendable {
    case claude, codex
}

/// One model response's token usage read from a local log.
struct TokenEntry: Equatable, Sendable {
    let provider: TokenProvider
    /// Dedup key. Claude: message id + request id. Codex: file path + byte offset.
    let key: String
    let timestamp: Date
    /// Tokens that become churu: uncached input + cache writes + output. Cache reads are excluded.
    let processed: Int
    /// Kept for display only; never counted toward churu.
    let cacheRead: Int
    /// Per-model buckets for API-price estimates. Churu accounting still uses `processed`.
    var billing: [BillableUsage] = []
}

/// Parses single JSONL lines from Claude Code and Codex logs.
enum TokenLogParser {
    /// A Claude Code `assistant` line. Server-side helper calls (advisor) are only in `usage.iterations`
    /// entries whose type is not `message`, so they are added on top of the top-level usage.
    static func claudeEntry(line: Data, fallbackKey: String) -> TokenEntry? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["type"] as? String == "assistant",
              let message = object["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let stamp = object["timestamp"] as? String,
              let timestamp = parseTimestamp(stamp)
        else { return nil }
        var input = int(usage["input_tokens"]), cacheWrite = int(usage["cache_creation_input_tokens"])
        var output = int(usage["output_tokens"]), cacheRead = int(usage["cache_read_input_tokens"])
        let model = message["model"] as? String
        var billing = [billable(usage, model: model)]
        for case let iteration as [String: Any] in usage["iterations"] as? [Any] ?? []
        where (iteration["type"] as? String ?? "message") != "message" {
            input += int(iteration["input_tokens"])
            cacheWrite += int(iteration["cache_creation_input_tokens"])
            output += int(iteration["output_tokens"])
            cacheRead += int(iteration["cache_read_input_tokens"])
            billing.append(billable(iteration, model: iteration["model"] as? String))
        }
        let key: String
        if let id = message["id"] as? String {
            key = "\(id):\(object["requestId"] as? String ?? "")"
        } else {
            key = "\(fallbackKey):\(object["uuid"] as? String ?? "")"
        }
        return TokenEntry(provider: .claude, key: key, timestamp: timestamp,
                          processed: input + cacheWrite + output, cacheRead: cacheRead, billing: billing)
    }

    /// A Codex `token_count` event. `last_token_usage` is this turn's delta; `total_token_usage` is cumulative
    /// per session and must not be summed. Codex `input_tokens` already includes `cached_input_tokens`.
    static func codexEntry(line: Data, key: String, model: String? = nil) -> TokenEntry? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let last = info["last_token_usage"] as? [String: Any],
              let stamp = object["timestamp"] as? String,
              let timestamp = parseTimestamp(stamp)
        else { return nil }
        let cached = int(last["cached_input_tokens"])
        let write = int(last["cache_write_input_tokens"])
        let processed = max(0, int(last["input_tokens"]) - cached) + int(last["output_tokens"])
        let billing = BillableUsage(model: model, input: max(0, int(last["input_tokens"]) - cached - write),
                                    cachedInput: cached, cacheWrite5m: write, cacheWrite1h: 0,
                                    output: int(last["output_tokens"]))
        return TokenEntry(provider: .codex, key: key, timestamp: timestamp,
                          processed: processed, cacheRead: cached, billing: [billing])
    }

    private static func billable(_ usage: [String: Any], model: String?) -> BillableUsage {
        let cache = usage["cache_creation"] as? [String: Any] ?? [:]
        let write5m = int(cache["ephemeral_5m_input_tokens"])
        let write1h = int(cache["ephemeral_1h_input_tokens"])
        let totalWrite = int(usage["cache_creation_input_tokens"])
        let speed = usage["speed"] as? String
        let geo = usage["inference_geo"] as? String
        let tier = usage["service_tier"] as? String
        let standard = (speed == nil || speed == "standard")
            && (geo == nil || geo == "global" || geo == "not_available")
            && (tier == nil || tier == "standard")
            && (totalWrite == write5m + write1h)
        return BillableUsage(model: model, input: int(usage["input_tokens"]),
                             cachedInput: int(usage["cache_read_input_tokens"]),
                             cacheWrite5m: write5m, cacheWrite1h: write1h,
                             output: int(usage["output_tokens"]), standardPricing: standard)
    }

    /// Log timestamps carry milliseconds (`2026-10-09T19:32:04.447Z`); the default formatter rejects them.
    static func parseTimestamp(_ text: String) -> Date? {
        fractionalFormatter.date(from: text) ?? plainFormatter.date(from: text)
    }

    // ISO8601DateFormatter is thread-safe for parsing.
    nonisolated(unsafe) private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) private static let plainFormatter = ISO8601DateFormatter()

    private static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
}

/// Reads token usage from local agent logs incrementally: each refresh reads only bytes appended since the last one.
/// Not thread-safe; call from one queue.
final class TokenUsageReader {
    struct Roots {
        var claude: [URL]
        var codex: [URL]

        static var live: Roots {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return Roots(
                claude: [home.appendingPathComponent(".claude/projects"),
                         home.appendingPathComponent(".config/claude/projects")],
                codex: [home.appendingPathComponent(".codex/sessions"),
                        home.appendingPathComponent(".codex/archived_sessions")])
        }
    }

    private struct FileState {
        var offset: UInt64 = 0
        var entries: [TokenEntry] = []
        var model: String?
    }

    let roots: Roots
    private var files: [String: FileState] = [:]

    init(roots: Roots = .live) {
        self.roots = roots
    }

    /// Entries from log files modified at or after `since`. Claude duplicates (streaming chunks, resumed sessions,
    /// subagents) are merged across all files: the largest usage wins and the earliest timestamp is kept.
    func entries(modifiedSince since: Date) -> [TokenEntry] {
        var seen = Set<String>()
        for (provider, rootList) in [(TokenProvider.claude, roots.claude), (.codex, roots.codex)] {
            for root in rootList {
                for (url, size) in Self.jsonlFiles(in: root, modifiedSince: since) {
                    seen.insert(url.path)
                    read(url, size: size, provider: provider)
                }
            }
        }
        files = files.filter { seen.contains($0.key) }

        var claude: [String: TokenEntry] = [:]
        var result: [TokenEntry] = []
        for state in files.values {
            for entry in state.entries {
                guard entry.provider == .claude else { result.append(entry); continue }
                guard let existing = claude[entry.key] else { claude[entry.key] = entry; continue }
                let kept = entry.processed + entry.cacheRead > existing.processed + existing.cacheRead ? entry : existing
                claude[entry.key] = TokenEntry(provider: .claude, key: kept.key,
                                               timestamp: min(entry.timestamp, existing.timestamp),
                                               processed: kept.processed, cacheRead: kept.cacheRead,
                                               billing: kept.billing)
            }
        }
        return result + claude.values
    }

    private func read(_ url: URL, size: UInt64, provider: TokenProvider) {
        var state = files[url.path] ?? FileState()
        if size < state.offset { state = FileState() }  // truncated or replaced
        guard size > state.offset, let handle = try? FileHandle(forReadingFrom: url) else {
            files[url.path] = state
            return
        }
        defer { try? handle.close() }
        try? handle.seek(toOffset: state.offset)
        guard let data = try? handle.readToEnd(),
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n"))
        else {
            files[url.path] = state
            return
        }
        // Only complete lines; a line still being written is read on the next refresh.
        let complete = data[data.startIndex...lastNewline]
        let marker = provider == .claude ? Data("\"usage\"".utf8) : Data("\"token_count\"".utf8)
        var lineStart = complete.startIndex
        while lineStart < complete.endIndex {
            let lineEnd = complete[lineStart...].firstIndex(of: UInt8(ascii: "\n")) ?? complete.endIndex
            let line = complete[lineStart..<lineEnd]
            if provider == .codex, line.range(of: Data("\"turn_context\"".utf8)) != nil,
               let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
               object["type"] as? String == "turn_context",
               let payload = object["payload"] as? [String: Any], let model = payload["model"] as? String {
                state.model = model
            }
            if line.range(of: marker) != nil {
                let lineOffset = state.offset + UInt64(lineStart - complete.startIndex)
                let entry = provider == .claude
                    ? TokenLogParser.claudeEntry(line: Data(line), fallbackKey: url.path)
                    : TokenLogParser.codexEntry(line: Data(line), key: "\(url.path)#\(lineOffset)",
                                                model: state.model)
                if let entry { state.entries.append(entry) }
            }
            lineStart = lineEnd + 1
        }
        state.offset += UInt64(complete.count)
        files[url.path] = state
    }

    /// Recursive: Claude subagent logs live at `<session>/subagents/agent-*.jsonl`.
    static func jsonlFiles(in root: URL, modifiedSince since: Date) -> [(URL, UInt64)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return [] }
        var found: [(URL, UInt64)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate, modified >= since
            else { continue }
            found.append((url, UInt64(values.fileSize ?? 0)))
        }
        return found
    }
}
