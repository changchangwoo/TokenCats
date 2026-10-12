import Foundation
import Testing
@testable import TokenCatsCore

private let resources = resourcesURL

/// A store over a temp directory whose logs hold `tokens` processed today.
private struct Fixture {
    let dir: URL
    let service: StoreService
    let churuFile: JSONFile<ChuruLedger>
    let catsFile: JSONFile<CatHousehold>
    let inventoryFile: JSONFile<StoreInventory>

    init(tokens: Int, cats: CatHousehold? = nil, catsFileOverride: URL? = nil, free: Bool = false) throws {
        dir = try makeTempDirectory()
        let logs = dir.appendingPathComponent("claude/p")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let now = Date()
        let stamp = ISO8601DateFormatter().string(from: now.addingTimeInterval(-60))
        let line = #"{"type":"assistant","requestId":"r","timestamp":"\#(stamp)","message":{"id":"m","usage":{"input_tokens":\#(tokens),"output_tokens":0}}}"# + "\n"
        try line.write(to: logs.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)
        churuFile = JSONFile(url: dir.appendingPathComponent("churu.json"))
        // Installed before the log line so it counts.
        churuFile.save(ChuruLedger(installedAt: now.addingTimeInterval(-3_600)))
        catsFile = JSONFile(url: catsFileOverride ?? dir.appendingPathComponent("cats.json"))
        if let cats { catsFile.save(cats) }
        inventoryFile = JSONFile(url: dir.appendingPathComponent("inventory.json"))
        let themes = try RoomThemeCatalog(data: Data(contentsOf: resources.appendingPathComponent("room-themes.json")))
        let coats: Set<String> = ["black", "white", "cheese", "tuxedo", "tabby", "split", "siamese", "cream", "foxfire", "norwegian", "sphynx"]
        let catalog = try StoreCatalog(data: Data(contentsOf: resources.appendingPathComponent("store-catalog.json")),
                                       coats: coats, backgroundIDs: Set(themes.backgrounds.map(\.id)),
                                       defaultBackgroundID: themes.defaultID)
        let tracker = ChuruTracker(reader: TokenUsageReader(roots: .init(claude: [dir.appendingPathComponent("claude")], codex: [])),
                                   file: churuFile)
        service = StoreService(catalog: free ? catalog.freeForTesting() : catalog, tracker: tracker, catsFile: catsFile, inventoryFile: inventoryFile,
                               defaultBackground: themes.defaultID, drawableCoats: coats, seed: 9)
    }
}

struct StoreServiceTests {
    @Test func newHouseholdStartsWithOneCommonCat() throws {
        let fixture = try Fixture(tokens: 0)
        #expect(fixture.service.household.residents.count == 1)
        #expect(["black", "cheese", "split", "tabby"].contains(fixture.service.household.residents[0].coat))
        #expect(fixture.catsFile.load() == fixture.service.household)
    }

    @Test func buyingABoxAdoptsACatAndSpendsTheChuru() throws {
        let fixture = try Fixture(tokens: 25_000_000)
        let outcome = fixture.service.purchase(.catBox)
        guard case .adopted(let cat, let tier) = outcome.result else { Issue.record("\(outcome.result)"); return }
        #expect(cat.inRoom)
        #expect(tier.coats.contains(cat.coat))
        #expect(outcome.snapshot.balance == 15_000_000)
        #expect(outcome.household.residents.count == 2)
        #expect(fixture.catsFile.load()?.residents.count == 2)
        #expect(fixture.churuFile.load()?.spent == 10_000_000)
        #expect(fixture.inventoryFile.load()?.purchases.map(\.result) == [cat.id])
    }

    @Test func notEnoughChuruChangesNothing() throws {
        let fixture = try Fixture(tokens: 9_000_000)
        let catsBefore = fixture.catsFile.load()
        let outcome = fixture.service.purchase(.catBox)
        #expect(outcome.result == .insufficient(short: 1_000_000))
        #expect(fixture.catsFile.load() == catsBefore)
        #expect(fixture.churuFile.load()?.spent == 0)
        #expect(fixture.inventoryFile.load() == nil)
    }

    @Test func secondPurchaseSeesTheSpentBalance() throws {
        let fixture = try Fixture(tokens: 15_000_000)
        guard case .adopted = fixture.service.purchase(.catBox).result else { Issue.record("first failed"); return }
        #expect(fixture.service.purchase(.catBox).result == .insufficient(short: 5_000_000))
        #expect(fixture.churuFile.load()?.spent == 10_000_000)
    }

    @Test func backgroundIsBoughtOnce() throws {
        let fixture = try Fixture(tokens: 30_000_000)
        #expect(fixture.service.purchase(.background("night")).result == .backgroundOwned("night"))
        #expect(fixture.service.inventory.owns(background: "night"))
        #expect(fixture.service.purchase(.background("night")).result == .alreadyOwned)
        #expect(fixture.service.purchase(.background("cozy")).result == .alreadyOwned)
        #expect(fixture.churuFile.load()?.spent == 10_000_000)
        #expect(fixture.service.purchase(.background("moon")).result == .failed)
    }

    @Test func propIsBoughtOnceThenPlaced() throws {
        let fixture = try Fixture(tokens: 10_000_000)
        #expect(!fixture.service.setProp(.hideCrate, shown: true))
        #expect(!fixture.service.inventory.decor.shows(.hideCrate))
        #expect(fixture.service.purchase(.prop(.hideCrate)).result == .propOwned(.hideCrate))
        #expect(fixture.service.purchase(.prop(.hideCrate)).result == .alreadyOwned)
        #expect(fixture.service.purchase(.prop(.calendar)).result == .failed)
        #expect(fixture.churuFile.load()?.spent == 4_000_000)
        #expect(fixture.inventoryFile.load()?.owns(prop: .hideCrate) == true)
        #expect(fixture.inventoryFile.load()?.purchases.last?.product == "prop")
        #expect(fixture.service.setProp(.hideCrate, shown: true))
        #expect(fixture.inventoryFile.load()?.decor.shows(.hideCrate) == true)
        #expect(fixture.service.setProp(.hideCrate, shown: false))
        #expect(fixture.inventoryFile.load()?.decor.shows(.hideCrate) == false)
    }

    @Test func propShortOfChuruIsNotBought() throws {
        let fixture = try Fixture(tokens: 1_000_000)
        #expect(fixture.service.purchase(.prop(.hideCrate)).result == .insufficient(short: 3_000_000))
        #expect(!fixture.service.inventory.owns(prop: .hideCrate))
    }

    @Test func fullRoomSendsTheNewCatToStorage() throws {
        var full = CatHousehold(residents: [])
        for _ in 0..<4 { full.adopt(coat: "black") }
        let fixture = try Fixture(tokens: 20_000_000, cats: full)
        guard case .adopted(let cat, _) = fixture.service.purchase(.catBox).result else { Issue.record("no cat"); return }
        #expect(!cat.inRoom)
        #expect(fixture.service.household.storedResidents.map(\.id) == [cat.id])
    }

    @Test func aBigStorageStillTakesNewCats() throws {
        var many = CatHousehold(residents: [])
        for _ in 0..<60 { many.adopt(coat: "black") }
        let fixture = try Fixture(tokens: 20_000_000, cats: many)
        guard case .adopted(let cat, _) = fixture.service.purchase(.catBox).result else { Issue.record("no cat"); return }
        #expect(!cat.inRoom)
        #expect(fixture.service.household.residents.count == 61)
    }

    @Test func failedSaveKeepsTheChuru() throws {
        // cats.json's parent is a regular file, so saving it fails.
        let blocker = try makeTempDirectory().appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let fixture = try Fixture(tokens: 20_000_000, catsFileOverride: blocker.appendingPathComponent("cats.json"))
        #expect(fixture.service.purchase(.catBox).result == .failed)
        #expect(fixture.churuFile.load()?.spent == 0)
    }

    @Test func movesGoThroughTheServiceAndAreSaved() throws {
        var two = CatHousehold(residents: [])
        two.adopt(coat: "black")
        two.adopt(coat: "white")
        let fixture = try Fixture(tokens: 0, cats: two)
        #expect(fixture.service.move(id: "white-1", toRoom: false) == .success(fixture.service.household))
        #expect(fixture.catsFile.load()?.storedResidents.map(\.id) == ["white-1"])
        #expect(fixture.service.move(id: "black-1", toRoom: false) == .failure(.lastCatInRoom))
    }

    @Test func releasesGoThroughTheServiceAndAreSaved() throws {
        var two = CatHousehold(residents: [])
        two.adopt(coat: "black")
        two.adopt(coat: "white")
        let fixture = try Fixture(tokens: 0, cats: two)
        #expect(fixture.service.release(id: "white-1") == .success(fixture.service.household))
        #expect(fixture.catsFile.load()?.residents.map(\.id) == ["black-1"])
        #expect(fixture.service.release(id: "black-1") == .failure(.lastCatInRoom))
    }

    @Test func failedMoveSaveIsReported() throws {
        var two = CatHousehold(residents: [])
        two.adopt(coat: "black")
        two.adopt(coat: "white")
        let fixture = try Fixture(tokens: 0, cats: two)
        // A directory where cats.json should be makes the next save fail.
        try FileManager.default.removeItem(at: fixture.catsFile.url)
        try FileManager.default.createDirectory(at: fixture.catsFile.url, withIntermediateDirectories: false)
        #expect(fixture.service.move(id: "white-1", toRoom: false) == .failure(.saveFailed))
        #expect(fixture.service.household.storedResidents.isEmpty)
    }

    @Test func testingModeBuysWithNoChuru() throws {
        let fixture = try Fixture(tokens: 0, free: true)
        guard case .adopted = fixture.service.purchase(.catBox).result else { Issue.record("box not free"); return }
        #expect(fixture.service.purchase(.background("night")).result == .backgroundOwned("night"))
        #expect(fixture.service.household.residents.count == 2)
        #expect(fixture.churuFile.load()?.spent == 0)
        #expect(fixture.service.inventory.purchases.map(\.price) == [0, 0])
    }

    @Test func swapIsSaved() throws {
        var full = CatHousehold(residents: [])
        for _ in 0..<4 { full.adopt(coat: "black") }
        full.adopt(coat: "white")
        let fixture = try Fixture(tokens: 0, cats: full)
        #expect(fixture.service.swap(roomID: "black-2", storedID: "white-1") == .success(fixture.service.household))
        #expect(fixture.catsFile.load()?.storedResidents.map(\.id) == ["black-2"])
        #expect(fixture.service.swap(roomID: "black-1", storedID: "black-3") == .failure(.notASwap))
    }

    @Test func takingTheCalendarDownIsSaved() throws {
        let fixture = try Fixture(tokens: 0)
        #expect(fixture.service.setProp(.calendar, shown: false))
        #expect(fixture.inventoryFile.load()?.decor.shows(.calendar) == false)
        #expect(!fixture.service.inventory.decor.shows(.calendar))
    }

    @Test func storeWithoutACatalogSellsNothing() throws {
        let fixture = try Fixture(tokens: 30_000_000)
        let closed = StoreService(catalog: nil, tracker: ChuruTracker(
            reader: TokenUsageReader(roots: .init(claude: [], codex: [])), file: fixture.churuFile),
            catsFile: fixture.catsFile, inventoryFile: fixture.inventoryFile, defaultBackground: "cozy",
            drawableCoats: ["black"], seed: 1)
        #expect(closed.purchase(.catBox).result == .failed)
    }
}
