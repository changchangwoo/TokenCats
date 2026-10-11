import Foundation
import Testing
@testable import TokenCatsCore

struct CostPricingTests {
    @Test func modelPricesEachTokenBucketSeparately() throws {
                let url = resourcesURL.appendingPathComponent("model-prices.json")
        let catalog = try PriceCatalog(data: Data(contentsOf: url))
        let usage = BillableUsage(model: "claude-opus-5-5", input: 1_000_000, cachedInput: 1_000_000,
                                  cacheWrite5m: 1_000_000, cacheWrite1h: 1_000_000,
                                  output: 1_000_000)
        let estimate = catalog.estimate(usage)
        #expect(abs(estimate.usd - 37.2) < 0.0001)
        #expect(estimate.unpricedTokens == 0)
    }

    @Test func unknownModelIsNotPresentedAsZeroCost() throws {
                let url = resourcesURL.appendingPathComponent("model-prices.json")
        let catalog = try PriceCatalog(data: Data(contentsOf: url))
        let estimate = catalog.estimate(BillableUsage(model: "unknown", input: 100, cachedInput: 0,
                                                       cacheWrite5m: 0, cacheWrite1h: 0, output: 50))
        #expect(estimate.usd == 0)
        #expect(estimate.unpricedTokens == 150)
        #expect(estimate.label == "—")
    }

    @Test func partialEstimateShowsOnlyTheDollarAmount() {
        let estimate = CostEstimate(usd: 4.25, pricedTokens: 1_000, unpricedTokens: 200)
        #expect(estimate.label == "$4.25")
    }
}
