import Foundation

/// Day totals scanned once from past logs, then advanced with the live ledger.
struct DailyHistory: Codable, Equatable, Sendable {
    var tokensByDay: [String: Int]
    let scannedAt: Date
}

/// Reads every agent log once, in chunks, keeping only day totals. The churu reader keeps whole files and every
/// entry in memory (about 2GB for 4GB of logs); this keeps a carry buffer and the Claude dedup keys.
enum DailyTokenScan {
    static func scan(roots: TokenUsageReader.Roots = .live, calendar: Calendar = .current,
                     chunkSize: Int = 4 << 20) -> [String: Int] {
        var days: [String: Int] = [:]
        var claude: [String: (processed: Int, day: String)] = [:]
        for (provider, rootList) in [(TokenProvider.claude, roots.claude), (.codex, roots.codex)] {
            let marker = Data((provider == .claude ? #""usage""# : #""token_count""#).utf8)
            for root in rootList {
                for (url, _) in TokenUsageReader.jsonlFiles(in: root, modifiedSince: .distantPast) {
                    forEachLine(in: url, chunkSize: chunkSize) { line in
                        guard line.range(of: marker) != nil else { return }
                        if provider == .claude {
                            guard let entry = TokenLogParser.claudeEntry(line: line, fallbackKey: url.path) else { return }
                            let day = ChuruLedger.dayKey(entry.timestamp, calendar)
                            let existing = claude[entry.key]
                            claude[entry.key] = (max(existing?.processed ?? 0, entry.processed), min(existing?.day ?? day, day))
                        } else if let entry = TokenLogParser.codexEntry(line: line, key: "") {
                            days[ChuruLedger.dayKey(entry.timestamp, calendar), default: 0] += entry.processed
                        }
                    }
                }
            }
        }
        for value in claude.values { days[value.day, default: 0] += value.processed }
        return days
    }

    /// Complete lines only; a last line without a newline is still being written and is skipped.
    static func forEachLine(in url: URL, chunkSize: Int, _ body: (Data) -> Void) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        var carry = Data()
        var reading = true
        while reading {
            // Parsing makes autoreleased Foundation objects per line; without a pool per chunk they pile up
            // for the whole scan (2.5GB over 4GB of logs).
            autoreleasepool {
                guard let chunk = try? handle.read(upToCount: max(1, chunkSize)), !chunk.isEmpty else {
                    reading = false
                    return
                }
                carry.append(chunk)
                var start = carry.startIndex
                while let newline = carry[start...].firstIndex(of: 0x0A) {
                    body(Data(carry[start..<newline]))
                    start = newline + 1
                }
                carry = Data(carry[start...])
            }
        }
    }
}

/// Day totals for the profile graph: the one-time scan for days before install, the churu ledger after it,
/// the live snapshot for today. Where two sources have the same day the larger wins.
enum ProfileHistory {
    static func dailyTokens(history: JSONFile<DailyHistory>, ledger: JSONFile<ChuruLedger>, today: Date,
                            todayTokens: Int, calendar: Calendar, now: Date = Date(),
                            scan: () -> [String: Int]) -> [String: Int] {
        let saved = history.load()
        var days = saved?.tokensByDay ?? scan()
        for (day, value) in ledger.load()?.frozenDays ?? [:] { days[day] = max(days[day] ?? 0, value.tokens) }
        let todayKey = ChuruLedger.dayKey(today, calendar)
        days[todayKey] = max(days[todayKey] ?? 0, todayTokens)
        if saved?.tokensByDay != days {
            history.save(DailyHistory(tokensByDay: days, scannedAt: saved?.scannedAt ?? now))
        }
        return days
    }
}
