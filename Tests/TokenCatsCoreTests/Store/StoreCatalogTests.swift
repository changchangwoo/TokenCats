import Foundation
import Testing
@testable import TokenCatsCore

private let resources = resourcesURL

private func coats() throws -> Set<String> {
    let data = try Data(contentsOf: resources.appendingPathComponent("CatArt/cat-assets.json"))
    return Set(try JSONDecoder().decode(CatAssetCatalog.self, from: data).cats.keys)
}

private func themes() throws -> RoomThemeCatalog {
    try RoomThemeCatalog(data: Data(contentsOf: resources.appendingPathComponent("room-themes.json")))
}

private func catalog(_ json: String? = nil) throws -> StoreCatalog {
    let data = try json.map { Data($0.utf8) } ?? Data(contentsOf: resources.appendingPathComponent("store-catalog.json"))
    let themes = try themes()
    return try StoreCatalog(data: data, coats: try coats(), backgroundIDs: Set(themes.backgrounds.map(\.id)),
                            defaultBackgroundID: themes.defaultID)
}

private func manifest(tiers: String = #"[{"id":"common","name":"흔함","weight":70,"coats":["black"]}]"#,
                      backgrounds: String = #"[{"id":"cozy","price":0},{"id":"night","price":10}]"#,
                      price: Int = 20, props: String? = nil, showcase: String? = nil, treat: String? = nil) -> String {
    let propList = props.map { #","props":\#($0)"# } ?? ""
    let showcaseList = showcase.map { #","showcase":\#($0)"# } ?? ""
    let treatOffer = treat.map { #","treat":\#($0)"# } ?? ""
    return #"{"schemaVersion":1,"catBox":{"price":\#(price),"tiers":\#(tiers)\#(showcaseList)},"backgrounds":\#(backgrounds)\#(propList)\#(treatOffer)}"#
}

struct StoreCatalogTests {
    @Test func bundledCatalogMatchesThePriceList() throws {
        let store = try catalog()
        #expect(store.catBox.price == 10_000_000)
        #expect(store.catBox.tiers.map(\.id) == ["common", "uncommon", "rare", "unique"])
        #expect(store.catBox.tiers.map { $0.name.resolve(for: Locale(identifier: "ko")) } == ["흔함", "드묾", "희귀", "유니크"])
        #expect(store.catBox.tiers.map { $0.name.resolve(for: Locale(identifier: "en")) } == ["Common", "Uncommon", "Rare", "Unique"])
        #expect(store.catBox.tiers.map(\.weight) == [50, 30, 15, 5])
        #expect(store.catBox.tiers.map(\.coats) == [["black", "cheese", "split", "tabby"], ["white", "tuxedo", "cream"], ["siamese", "sphynx"], ["foxfire", "norwegian"]])
        #expect(store.price(ofBackground: "cozy") == 0)
        #expect(store.price(ofBackground: "night") == 10_000_000)
        #expect(Set(store.backgrounds.map(\.id)) == Set(try themes().backgrounds.map(\.id)))
        #expect(store.price(ofProp: .hideCrate) == 4_000_000)
        #expect(store.price(ofProp: .catTower) == 8_000_000)
        #expect(store.price(ofProp: .yarnBall) == 1_000_000)
        #expect(store.propsForSale == [.yarnBall, .hideCrate, .catTower])
        #expect(store.price(ofProp: .calendar) == nil)
        #expect(store.treatPrice == 1_000_000)
    }

    @Test func treatIsOptionalAndMustCostSomething() throws {
        #expect(try catalog(manifest()).treatPrice == nil)
        #expect(try catalog(manifest(treat: #"{"price":5}"#)).treatPrice == 5)
        #expect(throws: StoreCatalog.Invalid.treatPrice) { try catalog(manifest(treat: #"{"price":0}"#)) }
        #expect(throws: StoreCatalog.Invalid.treatPrice) { try catalog(manifest(treat: #"{"price":-1}"#)) }
        #expect(try catalog(manifest(treat: #"{"price":5}"#)).freeForTesting().treatPrice == 0)
        #expect(try catalog(manifest()).freeForTesting().treatPrice == nil)
    }

    @Test func propsAreOptionalAndChecked() throws {
        #expect(try catalog(manifest()).props.isEmpty)
        #expect(try catalog(manifest(props: #"[{"id":"hideCrate","price":5}]"#)).price(ofProp: .hideCrate) == 5)
        #expect(throws: StoreCatalog.Invalid.unknownProp("tower")) {
            try catalog(manifest(props: #"[{"id":"tower","price":5}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.unknownProp("calendar")) {
            try catalog(manifest(props: #"[{"id":"calendar","price":5}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.duplicateProp) {
            try catalog(manifest(props: #"[{"id":"hideCrate","price":5},{"id":"hideCrate","price":6}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.propPrice) {
            try catalog(manifest(props: #"[{"id":"hideCrate","price":0}]"#))
        }
    }

    @Test func rejectsBrokenManifests() {
        #expect(throws: StoreCatalog.Invalid.boxPrice) { try catalog(manifest(price: 0)) }
        #expect(throws: StoreCatalog.Invalid.tierWeight) {
            try catalog(manifest(tiers: #"[{"id":"a","name":"a","weight":0,"coats":["black"]}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.duplicateCoat) {
            try catalog(manifest(tiers: #"[{"id":"a","name":"a","weight":1,"coats":["black"]},{"id":"b","name":"b","weight":1,"coats":["black"]}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.unknownCoat("calico")) {
            try catalog(manifest(tiers: #"[{"id":"a","name":"a","weight":1,"coats":["calico"]}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.unknownBackground("moon")) {
            try catalog(manifest(backgrounds: #"[{"id":"cozy","price":0},{"id":"moon","price":10}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.freeBackground) {
            try catalog(manifest(backgrounds: #"[{"id":"cozy","price":0},{"id":"night","price":0}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.freeBackground) {
            try catalog(manifest(backgrounds: #"[{"id":"cozy","price":5},{"id":"night","price":10}]"#))
        }
        #expect(throws: StoreCatalog.Invalid.duplicateBackground) {
            try catalog(manifest(backgrounds: #"[{"id":"cozy","price":0},{"id":"night","price":10},{"id":"night","price":10}]"#))
        }
    }

    @Test func boxOddsFollowTheTierWeights() throws {
        let store = try catalog()
        var generator = SeededGenerator(seed: 7)
        var counts: [String: Int] = [:]
        for _ in 0..<10_000 {
            let draw = try #require(store.drawCat(available: { _ in true }, using: &generator))
            counts[draw.tier.id, default: 0] += 1
            #expect(draw.tier.coats.contains(draw.coat))
        }
        #expect(abs(Double(counts["common", default: 0]) / 10_000 - 0.50) < 0.02)
        #expect(abs(Double(counts["uncommon", default: 0]) / 10_000 - 0.30) < 0.02)
        #expect(abs(Double(counts["rare", default: 0]) / 10_000 - 0.15) < 0.02)
        #expect(abs(Double(counts["unique", default: 0]) / 10_000 - 0.05) < 0.02)
    }

    @Test func sameSeedDrawsTheSameCat() throws {
        let store = try catalog()
        var first = SeededGenerator(seed: 42), second = SeededGenerator(seed: 42)
        #expect(store.drawCat(available: { _ in true }, using: &first)?.coat ==
                store.drawCat(available: { _ in true }, using: &second)?.coat)
    }

    @Test func emptyTierIsSkipped() throws {
        let store = try catalog()
        var generator = SeededGenerator(seed: 3)
        // Hide every rare coat so the rare tier is empty, however many cats it holds.
        let rare = Set(try #require(store.catBox.tiers.first { $0.id == "rare" }).coats)
        for _ in 0..<2_000 {
            let draw = try #require(store.drawCat(available: { !rare.contains($0) }, using: &generator))
            #expect(draw.tier.id != "rare")
            #expect(!rare.contains(draw.coat))
        }
        #expect(store.drawCat(available: { _ in false }, using: &generator) == nil)
    }

    @Test func firstCatIsTheBlackCat() throws {
        let store = try catalog()
        var generator = SeededGenerator(seed: 1)
        for _ in 0..<20 {
            #expect(store.firstCoat(available: { _ in true }, using: &generator) == "black")
        }
    }

    @Test func withoutBlackArtTheFirstCatComesFromTheCommonTier() throws {
        let store = try catalog()
        var generator = SeededGenerator(seed: 1)
        for _ in 0..<50 {
            let coat = try #require(store.firstCoat(available: { $0 != "black" }, using: &generator))
            #expect(["cheese", "split", "tabby"].contains(coat))
        }
    }

    @Test func testingModeMakesEverythingFree() throws {
        let free = try catalog().freeForTesting()
        #expect(free.catBox.price == 0)
        #expect(free.backgrounds.allSatisfy { $0.price == 0 })
        #expect(free.props.map(\.price) == [0, 0, 0])
        #expect(free.catBox.tiers == (try catalog()).catBox.tiers)
    }

    @Test func boxOddsSkipCoatsWithoutArt() throws {
        let store = try catalog()
        #expect(store.boxOdds(available: { _ in true }).map(\.percent) == [50, 30, 15, 5])
        // Without art for white and for every rare coat, the rare tier drops out and uncommon loses white.
        let rare = Set(try #require(store.catBox.tiers.first { $0.id == "rare" }).coats)
        let odds = store.boxOdds(available: { !rare.contains($0) && $0 != "white" })
        #expect(odds.map(\.tier.id) == ["common", "uncommon", "unique"])
        #expect(odds[1].tier.coats == ["tuxedo", "cream"])
        #expect(abs(odds.map(\.percent).reduce(0, +) - 100) < 0.000_1)
        #expect(abs(odds[0].percent - 50.0 / 85 * 100) < 0.000_1)
    }

    @Test func bundledShowcaseMixesTiersAndStopsAtEight() throws {
        #expect(try catalog().showcaseCoats(available: { _ in true }) ==
                ["black", "siamese", "cream", "tabby", "foxfire", "cheese", "tuxedo", "split"])
    }

    @Test func showcaseSkipsCoatsWithoutArtAndFillsFromTheTiers() throws {
        // Without siamese art the next box coat not already shown, in tier order, takes the free place.
        #expect(try catalog().showcaseCoats(available: { $0 != "siamese" }) ==
                ["black", "cream", "tabby", "foxfire", "cheese", "tuxedo", "split", "white"])
    }

    @Test func showcaseWithoutAListFollowsTheTiers() throws {
        let tiers = #"[{"id":"a","name":"a","weight":1,"coats":["black","white"]},{"id":"b","name":"b","weight":1,"coats":["tabby"]}]"#
        #expect(try catalog(manifest(tiers: tiers)).showcaseCoats(available: { _ in true }) == ["black", "white", "tabby"])
        #expect(try catalog(manifest(tiers: tiers, showcase: #"["tabby"]"#)).showcaseCoats(available: { _ in true }, limit: 2)
                == ["tabby", "black"])
    }

    @Test func showcaseNamesOnlyBoxCoatsOnce() throws {
        #expect(throws: StoreCatalog.Invalid.unknownCoat("white")) { try catalog(manifest(showcase: #"["white"]"#)) }
        #expect(throws: StoreCatalog.Invalid.duplicateCoat) { try catalog(manifest(showcase: #"["black","black"]"#)) }
    }

    @Test func eachCoatSharesItsTiersChanceEvenly() throws {
        let odds = try catalog().boxOdds(available: { _ in true })
        #expect(odds.map(\.percentPerCoat) == [12.5, 10, 7.5, 2.5])
    }
}
