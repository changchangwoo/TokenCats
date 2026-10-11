import Testing
@testable import TokenCatsCore

struct CatNamesTests {
    @Test func sameCoatsAreNumberedInAdoptionOrder() {
        var home = CatHousehold(residents: [])
        let first = home.adopt(coat: "cheese")
        let only = home.adopt(coat: "black")
        let second = home.adopt(coat: "cheese")
        #expect(CatNames.display(first, in: home) == CatDisplayName(coat: "cheese", ordinal: 1))
        #expect(CatNames.display(second, in: home) == CatDisplayName(coat: "cheese", ordinal: 2))
        #expect(CatNames.display(only, in: home) == CatDisplayName(coat: "black", ordinal: nil))
    }
}
