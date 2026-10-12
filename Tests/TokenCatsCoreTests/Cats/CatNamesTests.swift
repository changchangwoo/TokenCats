import Foundation
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

    @Test func aGivenNameWinsOverTheCoatName() throws {
        var home = CatHousehold(residents: [])
        let first = home.adopt(coat: "cheese")
        home.adopt(coat: "cheese")
        try home.rename(id: first.id, to: "Mochi")
        let named = home.residents[0]
        #expect(named.name == "Mochi")
        #expect(CatNames.display(named, in: home) == CatDisplayName(coat: "cheese", ordinal: 1, custom: "Mochi"))
        // The other cheese keeps its number.
        #expect(CatNames.display(home.residents[1], in: home) == CatDisplayName(coat: "cheese", ordinal: 2))
    }

    @Test func namesAreTrimmedCappedAndClearable() throws {
        var home = CatHousehold(residents: [])
        let cat = home.adopt(coat: "black")
        try home.rename(id: cat.id, to: "  Mochi  ")
        #expect(home.residents[0].name == "Mochi")
        try home.rename(id: cat.id, to: String(repeating: "x", count: 40))
        #expect(home.residents[0].name?.count == CatNames.maxNameLength)
        try home.rename(id: cat.id, to: "   ")
        #expect(home.residents[0].name == nil)
        #expect(CatNames.display(home.residents[0], in: home) == CatDisplayName(coat: "black", ordinal: nil))
        #expect(throws: CatHousehold.MoveError.unknownCat) { try home.rename(id: "ghost-1", to: "x") }
    }

    @Test func catsSavedBeforeNamesExistedHaveNone() throws {
        let data = Data(#"{"residents":[{"id":"black-1","coat":"black","inRoom":true}]}"#.utf8)
        let home = try JSONDecoder().decode(CatHousehold.self, from: data)
        #expect(home.residents[0].name == nil)
        var named = home
        try named.rename(id: "black-1", to: "Nabi")
        let round = try JSONDecoder().decode(CatHousehold.self, from: JSONEncoder().encode(named))
        #expect(round.residents[0].name == "Nabi")
    }
}
