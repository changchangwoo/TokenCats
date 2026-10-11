import Testing
@testable import TokenCatsCore

struct OfferStateTests {
    @Test func inUseComesBeforeOwnedAndOwnedBeforePrice() {
        #expect(OfferState.of(price: 10, balance: 0, owned: true, inUse: true) == .inUse)
        #expect(OfferState.of(price: 10, balance: 0, owned: true, inUse: false) == .owned)
        #expect(OfferState.of(price: 10, balance: 10, owned: false, inUse: false) == .affordable(price: 10))
        #expect(OfferState.of(price: 10_000_000, balance: 6_500_000, owned: false, inUse: false)
                == .short(price: 10_000_000, by: 3_500_000))
    }

    @Test func freeOffersAreAlwaysAffordable() {
        #expect(OfferState.of(price: 0, balance: 0, owned: false, inUse: false) == .affordable(price: 0))
    }
}
