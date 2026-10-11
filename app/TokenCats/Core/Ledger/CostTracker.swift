import Foundation

struct ProviderCostSummary: Equatable, Sendable {
    var tokens = 0
    var estimate = CostEstimate()

    mutating func add(_ entry: TokenEntry, catalog: PriceCatalog) {
        tokens += entry.processed
        if entry.billing.isEmpty {
            estimate.unpricedTokens += entry.processed + entry.cacheRead
        } else {
            for usage in entry.billing { estimate.add(catalog.estimate(usage)) }
        }
    }

    mutating func add(_ other: ProviderCostSummary) {
        tokens += other.tokens
        estimate.add(other.estimate)
    }
}

struct CostSnapshot: Equatable, Sendable {
    let today: [TokenProvider: ProviderCostSummary]
    let week: [TokenProvider: ProviderCostSummary]
    let dailyTokens: [String: Int]

    var todayTotal: ProviderCostSummary { Self.total(today) }
    var weekTotal: ProviderCostSummary { Self.total(week) }

    private static func total(_ providers: [TokenProvider: ProviderCostSummary]) -> ProviderCostSummary {
        var result = ProviderCostSummary()
        for summary in providers.values { result.add(summary) }
        return result
    }
}

/// Reads only files changed during the rolling seven-day window; the reader caches parsed entries between refreshes.
final class CostTracker: @unchecked Sendable {
    private let reader: TokenUsageReader
    private let catalog: PriceCatalog
    private let calendar: Calendar

    init(reader: TokenUsageReader, catalog: PriceCatalog, calendar: Calendar = .current) {
        self.reader = reader
        self.catalog = catalog
        self.calendar = calendar
    }

    static var live: CostTracker {
        CostTracker(reader: TokenUsageReader(), catalog: .bundled)
    }

    func refresh(now: Date = Date()) -> CostSnapshot {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: now) ?? now)
        let todayKey = ChuruLedger.dayKey(now, calendar)
        var today: [TokenProvider: ProviderCostSummary] = [:]
        var week: [TokenProvider: ProviderCostSummary] = [:]
        var dailyTokens: [String: Int] = [:]
        for entry in reader.entries(modifiedSince: start) where entry.timestamp >= start && entry.timestamp <= now {
            week[entry.provider, default: ProviderCostSummary()].add(entry, catalog: catalog)
            let day = ChuruLedger.dayKey(entry.timestamp, calendar)
            dailyTokens[day, default: 0] += entry.processed
            if day == todayKey {
                today[entry.provider, default: ProviderCostSummary()].add(entry, catalog: catalog)
            }
        }
        return CostSnapshot(today: today, week: week, dailyTokens: dailyTokens)
    }
}
