import Foundation

/// The API-rate equivalent of one recorded model call. It is not a subscription invoice.
struct BillableUsage: Equatable, Sendable {
    let model: String?
    let input: Int
    let cachedInput: Int
    let cacheWrite5m: Int
    let cacheWrite1h: Int
    let output: Int
    var standardPricing: Bool = true

    var total: Int { input + cachedInput + cacheWrite5m + cacheWrite1h + output }
}

struct CostEstimate: Equatable, Sendable {
    var usd = 0.0
    var pricedTokens = 0
    var unpricedTokens = 0

    mutating func add(_ other: CostEstimate) {
        usd += other.usd
        pricedTokens += other.pricedTokens
        unpricedTokens += other.unpricedTokens
    }

    var label: String {
        guard pricedTokens > 0 else { return "—" }
        let amount = String(format: "%.2f", usd)
        return "$\(amount)"
    }
}

struct PriceCatalog: Sendable {
    struct Rate: Codable, Sendable {
        let input: Double
        let cachedInput: Double
        let cacheWrite5m: Double
        let cacheWrite1h: Double
        let output: Double
    }

    private struct Manifest: Decodable {
        let schemaVersion: Int
        let asOf: String
        let pricesPerMillion: [String: Rate]
    }

    let asOf: String
    private let rates: [String: Rate]

    init(data: Data) throws {
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.schemaVersion == 1 else { throw NSError(domain: "PriceCatalog", code: 1) }
        asOf = manifest.asOf
        rates = manifest.pricesPerMillion
    }

    private init(asOf: String, rates: [String: Rate]) {
        self.asOf = asOf
        self.rates = rates
    }

    func estimate(_ usage: BillableUsage) -> CostEstimate {
        guard usage.total > 0 else { return CostEstimate() }
        guard usage.standardPricing, let model = usage.model, let rate = rates[model] else {
            return CostEstimate(unpricedTokens: usage.total)
        }
        let usd = (Double(usage.input) * rate.input
                   + Double(usage.cachedInput) * rate.cachedInput
                   + Double(usage.cacheWrite5m) * rate.cacheWrite5m
                   + Double(usage.cacheWrite1h) * rate.cacheWrite1h
                   + Double(usage.output) * rate.output) / 1_000_000
        return CostEstimate(usd: usd, pricedTokens: usage.total)
    }

    static let bundled: PriceCatalog = {
        guard let url = Bundle.main.url(forResource: "model-prices", withExtension: "json"),
              let data = try? Data(contentsOf: url), let catalog = try? PriceCatalog(data: data)
        else { return PriceCatalog(asOf: "", rates: [:]) }
        return catalog
    }()
}
