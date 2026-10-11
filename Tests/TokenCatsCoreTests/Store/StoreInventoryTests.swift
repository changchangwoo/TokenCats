import Foundation
import Testing
@testable import TokenCatsCore

struct StoreInventoryTests {
    @Test func startsOwningOnlyTheDefaultBackground() throws {
        let file = JSONFile<StoreInventory>(url: try makeTempDirectory().appendingPathComponent("inventory.json"))
        let inventory = StoreInventory.load(from: file, defaultBackground: "cozy")
        #expect(inventory.ownedBackgrounds == ["cozy"])
        #expect(inventory.purchases.isEmpty)
    }

    @Test func keepsPurchasesAcrossLoads() throws {
        let file = JSONFile<StoreInventory>(url: try makeTempDirectory().appendingPathComponent("inventory.json"))
        var inventory = StoreInventory.load(from: file, defaultBackground: "cozy")
        inventory.own(background: "pool")
        inventory.record(StorePurchase(at: Date(timeIntervalSince1970: 0), product: "background", price: 10, result: "pool"))
        #expect(file.save(inventory))
        let reloaded = StoreInventory.load(from: file, defaultBackground: "cozy")
        #expect(reloaded.owns(background: "pool"))
        #expect(reloaded.purchases.count == 1)
    }

    @Test func olderFilesKeepTheCalendarUp() throws {
        let file = JSONFile<StoreInventory>(url: try makeTempDirectory().appendingPathComponent("inventory.json"))
        try Data(#"{"ownedBackgrounds":["cozy","pool"],"purchases":[]}"#.utf8).write(to: file.url)
        let inventory = StoreInventory.load(from: file, defaultBackground: "cozy")
        #expect(inventory.decor == .starter)
        #expect(inventory.owns(background: "pool"))
    }

    @Test func decorChangesAreSaved() throws {
        let file = JSONFile<StoreInventory>(url: try makeTempDirectory().appendingPathComponent("inventory.json"))
        var inventory = StoreInventory.load(from: file, defaultBackground: "cozy")
        inventory.set(.calendar, shown: false)
        #expect(file.save(inventory))
        #expect(!StoreInventory.load(from: file, defaultBackground: "cozy").decor.shows(.calendar))
    }

    @Test func defaultBackgroundIsAlwaysOwned() throws {
        let file = JSONFile<StoreInventory>(url: try makeTempDirectory().appendingPathComponent("inventory.json"))
        try Data(#"{"ownedBackgrounds":["pool"],"purchases":[]}"#.utf8).write(to: file.url)
        #expect(StoreInventory.load(from: file, defaultBackground: "cozy").ownedBackgrounds == ["cozy", "pool"])
    }

    @Test func ownsOnlyTheCalendarUntilAPropIsBought() throws {
        let file = JSONFile<StoreInventory>(url: try makeTempDirectory().appendingPathComponent("inventory.json"))
        var inventory = StoreInventory.load(from: file, defaultBackground: "cozy")
        #expect(inventory.owns(prop: .calendar))
        #expect(!inventory.owns(prop: .hideCrate))
        inventory.own(prop: .hideCrate)
        #expect(file.save(inventory))
        #expect(StoreInventory.load(from: file, defaultBackground: "cozy").owns(prop: .hideCrate))
    }

    @Test func olderFilesOwnNoBoughtProps() throws {
        let file = JSONFile<StoreInventory>(url: try makeTempDirectory().appendingPathComponent("inventory.json"))
        try Data(#"{"ownedBackgrounds":["cozy"],"purchases":[]}"#.utf8).write(to: file.url)
        let inventory = StoreInventory.load(from: file, defaultBackground: "cozy")
        #expect(inventory.ownedProps.isEmpty)
        #expect(inventory.owns(prop: .calendar))
    }
}
