import Testing
@testable import TokenCatsCore

struct TokenCountTests {
    @Test func compactsLikeTheChuruFooter() {
        #expect(TokenCount.compact(850) == "850")
        #expect(TokenCount.compact(12_300) == "12K")
        #expect(TokenCount.compact(3_400_000) == "3.4M")
        #expect(TokenCount.compact(1_200_000_000) == "1.2B")
    }

    /// Prices are round numbers, so the store shows "20M", not "20.0M".
    @Test func priceDropsTheZeroFraction() {
        #expect(TokenCount.price(20_000_000) == "20M")
        #expect(TokenCount.price(3_400_000) == "3.4M")
        #expect(TokenCount.price(5_000) == "5K")
        #expect(TokenCount.price(850) == "850")
    }
}
