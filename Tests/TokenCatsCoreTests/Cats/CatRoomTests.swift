import Foundation
import Testing
@testable import TokenCatsCore

private func household(_ count: Int) -> CatHousehold {
    var household = CatHousehold(residents: [])
    for index in 0..<count { household.adopt(coat: index % 2 == 0 ? "black" : "white") }
    return household
}

struct CatHouseholdTests {
    @Test func roomHoldsFourAndLaterAdoptionsWaitInStorage() {
        #expect(CatHousehold.roomCapacity == 4)
        var home = household(4)
        #expect(home.isRoomFull)
        let fifth = home.adopt(coat: "tabby")
        #expect(fifth.inRoom == false)
        #expect(home.roomResidents.count == 4)
        #expect(home.storedResidents.map(\.id) == ["tabby-1"])
    }

    @Test func storageHasNoLimit() {
        var home = CatHousehold(residents: [])
        for _ in 0..<80 { home.adopt(coat: "black") }
        #expect(home.residents.count == 80)
        #expect(home.roomResidents.count == 4)
        #expect(home.storedResidents.count == 76)
        #expect(CatHousehold(residents: home.residents).residents.count == 80)
    }

    @Test func catsSharingACoatGetDistinctIds() {
        var home = CatHousehold(residents: [])
        let first = home.adopt(coat: "white")
        let second = home.adopt(coat: "white")
        #expect(first.id == "white-1")
        #expect(second.id == "white-2")
        #expect(CatHousehold(residents: [first, first]).residents.count == 1)
    }

    @Test func swapTradesARoomCatForAStoredOne() throws {
        var home = household(4)
        home.adopt(coat: "tabby")
        try home.swap(roomID: "white-1", storedID: "tabby-1")
        #expect(home.roomResidents.map(\.id).contains("tabby-1"))
        #expect(home.storedResidents.map(\.id) == ["white-1"])
        #expect(throws: CatHousehold.MoveError.notASwap) { try home.swap(roomID: "black-1", storedID: "black-2") }
        #expect(throws: CatHousehold.MoveError.notASwap) { try home.swap(roomID: "white-1", storedID: "black-1") }
        #expect(throws: CatHousehold.MoveError.unknownCat) { try home.swap(roomID: "nobody", storedID: "white-1") }
    }

    @Test func movingRespectsTheRoomLimits() throws {
        var home = household(4)
        home.adopt(coat: "tabby")
        #expect(throws: CatHousehold.MoveError.roomFull) { try home.move(id: "tabby-1", toRoom: true) }
        try home.move(id: "black-1", toRoom: false)
        try home.move(id: "tabby-1", toRoom: true)
        #expect(home.roomResidents.map(\.id).contains("tabby-1"))
        #expect(throws: CatHousehold.MoveError.unknownCat) { try home.move(id: "nobody", toRoom: true) }

        var single = household(1)
        #expect(throws: CatHousehold.MoveError.lastCatInRoom) { try single.move(id: "black-1", toRoom: false) }
    }

    @Test func releasingACatRemovesItForGood() throws {
        var home = household(4)
        home.adopt(coat: "tabby")
        try home.release(id: "tabby-1")
        #expect(!home.residents.contains { $0.id == "tabby-1" })
        try home.release(id: "black-2")
        #expect(home.roomResidents.count == 3)
        #expect(throws: CatHousehold.MoveError.unknownCat) { try home.release(id: "nobody") }
        // A new cat of a released coat never takes an id still in use.
        let next = home.adopt(coat: "black")
        #expect(home.residents.filter { $0.id == next.id }.count == 1)

        var single = household(1)
        #expect(throws: CatHousehold.MoveError.lastCatInRoom) { try single.release(id: "black-1") }
        #expect(single.residents.count == 1)
    }

    @Test func decodesOldFilesWithEveryCatInTheRoom() throws {
        let old = #"{"residents":[{"id":"black-1","coat":"black"},{"id":"white-1","coat":"white"},{"id":"cheese-1","coat":"cheese"},{"id":"tuxedo-1","coat":"tuxedo"}]}"#
        let dir = try makeTempDirectory()
        let file = JSONFile<CatHousehold>(url: dir.appendingPathComponent("cats.json"))
        try Data(old.utf8).write(to: file.url)
        let home = CatHousehold.load(from: file, firstCoat: { "tabby" })
        #expect(home.roomResidents.map(\.id) == ["black-1", "white-1", "cheese-1", "tuxedo-1"])
        #expect(home.storedResidents.isEmpty)
    }

    @Test func overfullRoomFromAFileSendsTheRestToStorage() {
        let records = (1...6).map { CatResidentRecord(id: "black-\($0)", coat: "black") }
        let home = CatHousehold(residents: records)
        #expect(home.roomResidents.count == 4)
        #expect(home.storedResidents.map(\.id) == ["black-5", "black-6"])
    }

    @Test func firstLaunchStartsWithOneCatAndKeepsLaterAdoptions() throws {
        let file = JSONFile<CatHousehold>(url: try makeTempDirectory().appendingPathComponent("cats.json"))
        var home = CatHousehold.load(from: file, firstCoat: { "cheese" })
        #expect(home.residents.map(\.id) == ["cheese-1"])
        home.adopt(coat: "black")
        file.save(home)
        #expect(CatHousehold.load(from: file, firstCoat: { "white" }).residents.map(\.id) == ["cheese-1", "black-1"])
    }
}

struct CatRoomTests {
    @Test func everyCoatUsesTheQuickerWalkingSpeed() {
        func firstStep(for coat: String) -> Double {
            var room = CatRoom(household: CatHousehold(residents: [
                CatResidentRecord(id: "test-1", coat: coat),
            ]))
            var previousX = room.step(dt: 0, now: 0, width: 600)[0].x
            for tick in 1...100 {
                let cat = room.step(dt: 0.125, now: Double(tick) * 0.125,
                                    width: 600)[0]
                if cat.clip == .walkRight { return cat.x - previousX }
                previousX = cat.x
            }
            return 0
        }

        for coat in ["black", "white", "tabby", "cheese", "tuxedo", "split", "siamese", "cream", "foxfire", "norwegian", "sphynx"] {
            let step = firstStep(for: coat)
            #expect(step == 7.5)
        }
    }

    @Test func showsOnlyCatsThatFitWithoutOverlapping() {
        var room = CatRoom(household: household(4))
        let cats = room.step(dt: 0.1, now: 0, width: 300)
        #expect(cats.count == 3)
        #expect(room.hiddenCount == 1)
        #expect(Set(cats.map(\.id)).count == 3)
        let xs = cats.map(\.x)
        #expect(xs.allSatisfy { $0 >= 48 && $0 <= 252 })
        #expect(xs == xs.sorted())
        #expect(zip(xs, xs.dropFirst()).allSatisfy { pair in pair.1 - pair.0 >= 100 })
    }

    @Test func housematesDoNotMoveInLockstep() {
        var room = CatRoom(household: household(4))
        var differentFrames = false
        for step in 0..<600 {
            let cats = room.step(dt: 0.1, now: Double(step) * 0.1, width: 600)
            if Set(cats.map { "\($0.clip)\($0.clipIndex)" }).count > 1 { differentFrames = true }
            #expect(cats.allSatisfy { $0.x >= 48 && $0.x <= 552 })
        }
        #expect(differentFrames)
    }

    @Test func pettingReachesOnlyTheCatUnderThePointer() {
        var room = CatRoom(household: household(2))
        let cats = room.step(dt: 0.1, now: 0, width: 600)
        let second = cats[1]
        let petted = room.pet(at: 1, point: RoomPoint(x: second.x, y: 120), baseline: 170)
        #expect(petted == second.id)
        let after = room.step(dt: 0.1, now: 1.05, width: 600)
        #expect(after[0].petFrame == nil)
        #expect(after[1].petFrame != nil)
        #expect(after[1].heartProgress != nil)
        #expect(room.pet(at: 2, point: RoomPoint(x: 300, y: 10), baseline: 170) == nil)
    }

    @Test func narrowRoomHidesExtraCatsAndOnlyVisibleCatsCanBeClicked() {
        var room = CatRoom(household: household(4))
        let cats = room.step(dt: 0.1, now: 0, width: 200)
        #expect(cats.count == 2)
        #expect(room.hiddenCount == 2)
        let point = RoomPoint(x: cats[1].x, y: 120)
        let index = room.catIndex(at: point, baseline: 170)
        #expect(index == 1)
        #expect(room.pet(at: 1, point: point, baseline: 170) == cats[1].id)
    }

    @Test func walkingCatsPassOnTheSameFloor() {
        var room = CatRoom(household: household(6))
        var overlapped = false
        for tick in 0..<2_000 {
            let cats = room.step(dt: 0.1, now: Double(tick) * 0.1, width: 600)
            #expect(cats.allSatisfy { $0.yOffset == 0 })
            for left in 0..<cats.count {
                for right in (left + 1)..<cats.count where abs(cats[left].x - cats[right].x) < 40 {
                    overlapped = true
                }
            }
        }
        #expect(overlapped)
    }

    @Test(arguments: [3, 4], [400.0, 416.0])
    func crowdedCatsExchangePlacesInsteadOfFreezing(count: Int, width: Double) {
        var room = CatRoom(household: household(count))
        let initial = room.step(dt: 0.1, now: 0, width: width)
        var movedIDs = Set<String>()
        var exchanged = false
        for tick in 1..<1_200 {
            let cats = room.step(dt: 0.1, now: Double(tick) * 0.1, width: width)
            for (cat, start) in zip(cats, initial) where abs(cat.x - start.x) > 20 {
                movedIDs.insert(cat.id)
            }
            exchanged = exchanged || cats[0].x > cats[1].x
            for left in 0..<cats.count {
                for right in (left + 1)..<cats.count where abs(cats[left].x - cats[right].x) < 10 {
                    #expect(cats[left].yOffset == 0 && cats[right].yOffset == 0)
                }
            }
        }
        #expect(movedIDs.count == count)
        #expect(exchanged)
    }

    @Test func aFullRoomAlsoMovesInAWideRoom() {
        var room = CatRoom(household: household(4))
        let initial = room.step(dt: 0.1, now: 0, width: 1_200)
        var movedIDs = Set<String>()
        for tick in 1..<1_200 {
            let cats = room.step(dt: 0.1, now: Double(tick) * 0.1, width: 1_200)
            for (cat, start) in zip(cats, initial) where abs(cat.x - start.x) > 20 {
                movedIDs.insert(cat.id)
            }
        }
        #expect(movedIDs.count == 4)
    }

    @Test func crowdedRoomUsesDifferentNeighborsOverTime() {
        var room = CatRoom(household: household(5))
        var previous = room.step(dt: 0.1, now: 0, width: 616)
            .sorted { $0.x < $1.x }.map(\.id)
        var pairs = Set<String>()
        for tick in 1..<1_200 {
            let order = room.step(dt: 0.1, now: Double(tick) * 0.1, width: 616)
                .sorted { $0.x < $1.x }.map(\.id)
            let changed = zip(previous, order).filter { $0.0 != $0.1 }
            if changed.count == 2 {
                pairs.insert(changed.map(\.0).sorted().joined(separator: ":"))
            }
            previous = order
        }
        #expect(pairs.count >= 3)
    }

    @Test func catsStillWalkWhenThereIsRoom() {
        var room = CatRoom(household: household(2))
        let initial = room.step(dt: 0.1, now: 0, width: 600).map(\.x)
        var moved = false
        for tick in 1..<400 {
            let xs = room.step(dt: 0.1, now: Double(tick) * 0.1, width: 600).map(\.x)
            if xs != initial { moved = true }
        }
        #expect(moved)
    }

    @Test func fourCatsStartNearEachOtherInsteadOfFillingTheWholeRoom() {
        var room = CatRoom(household: household(4))
        let cats = room.step(dt: 0.1, now: 0, width: 1_200)
        let xs = cats.map(\.x)
        #expect(xs.last! - xs.first! <= 480)
        #expect(zip(xs, xs.dropFirst()).allSatisfy { pair in pair.1 - pair.0 >= 100 })
    }

    @Test func catPassesAHousemateWithoutFullyCoveringIt() {
        var room = CatRoom(household: household(2))
        var crossed = false
        var overlapped = false
        for tick in 0..<1_200 {
            let cats = room.step(dt: 0.1, now: Double(tick) * 0.1, width: 600)
            if cats[0].x > cats[1].x { crossed = true }
            if abs(cats[0].x - cats[1].x) < 40 {
                overlapped = true
                #expect(cats[0].yOffset == 0 && cats[1].yOffset == 0)
            }
        }
        #expect(crossed)
        #expect(overlapped)
    }

    @Test func pettingDuringASwapPausesOnlyTheTouchedCat() {
        var room = CatRoom(household: household(4))
        var walkers: [CatSceneCat] = []
        var touchTime = 0.0
        for tick in 0..<600 {
            let now = Double(tick) * 0.1
            let cats = room.step(dt: 0.1, now: now, width: 480)
            let moving = cats.filter { $0.clip == .walkRight || $0.clip == .walkLeft }
            if moving.count == 2 && abs(moving[0].x - moving[1].x) > 104 {
                walkers = moving
                touchTime = now
                break
            }
        }
        #expect(walkers.count == 2)
        guard walkers.count == 2 else { return }
        let first = walkers[0], second = walkers[1]
        #expect(room.pet(at: touchTime, point: RoomPoint(x: first.x, y: 110), baseline: 170) == first.id)
        var partnerContinued = false
        for tick in 1...4 {
            let cats = room.step(dt: 0.1, now: touchTime + Double(tick) * 0.1,
                                 width: 480)
            #expect(cats.first { $0.id == first.id }?.x == first.x)
            partnerContinued = partnerContinued || cats.first { $0.id == second.id }?.x != second.x
            #expect(cats.first { $0.id == first.id }?.petFrame != nil)
        }
        #expect(partnerContinued)
        room.endPet(at: touchTime + 0.4)
        for tick in 5...9 {
            let cats = room.step(dt: 0.1, now: touchTime + Double(tick) * 0.1,
                                 width: 480)
            #expect(cats.first { $0.id == first.id }?.x == first.x)
        }
        var resumed = false
        for tick in 10...30 {
            let cats = room.step(dt: 0.1, now: touchTime + Double(tick) * 0.1,
                                 width: 480)
            if cats.first(where: { $0.id == first.id })!.x != first.x { resumed = true }
        }
        #expect(resumed)
    }

    @Test func roomDrawsOnlyCatsThatAreInTheRoom() throws {
        var home = household(3)
        try home.move(id: "white-1", toRoom: false)
        var room = CatRoom(household: home)
        #expect(room.step(dt: 0.1, now: 0, width: 600).map(\.id) == ["black-1", "black-2"])
    }

    @Test func syncKeepsHousematesWhereTheyStand() {
        var home = household(2)
        var room = CatRoom(household: home)
        let before = room.step(dt: 0, now: 0, width: 600)
        home.adopt(coat: "tabby")
        room.sync(home)
        let after = room.step(dt: 0, now: 0, width: 600)
        #expect(after.count == 3)
        #expect(after.prefix(2).map(\.x) == before.map(\.x))
        let newcomer = after[2]
        #expect(before.allSatisfy { abs($0.x - newcomer.x) >= CatRoom.minCenterSpacing })
        #expect(newcomer.x >= 48 && newcomer.x <= 552)
    }

    @Test func syncRemovesCatsSentToStorage() throws {
        var home = household(3)
        var room = CatRoom(household: home)
        _ = room.step(dt: 0.1, now: 0, width: 600)
        try home.move(id: "white-1", toRoom: false)
        room.sync(home)
        #expect(room.step(dt: 0.1, now: 0.1, width: 600).map(\.id) == ["black-1", "black-2"])
    }

    @Test func hiddenCatTakesTheFreedSpot() throws {
        var home = household(4)
        var room = CatRoom(household: home)
        let before = room.step(dt: 0, now: 0, width: 300)
        #expect(before.count == 3)
        try home.move(id: before[1].id, toRoom: false)
        room.sync(home)
        let after = room.step(dt: 0, now: 0, width: 300)
        #expect(after.count == 3)
        #expect(room.hiddenCount == 0)
        let arrived = try #require(after.first { cat in !before.contains { $0.id == cat.id } })
        #expect(after.filter { $0.id != arrived.id }.allSatisfy { abs($0.x - arrived.x) >= 60 })
    }

    @Test func syncDuringASwapKeepsCatsOnTheFloor() throws {
        var home = household(4)
        var room = CatRoom(household: home)
        for tick in 0..<50 { _ = room.step(dt: 0.1, now: Double(tick) * 0.1, width: 616) }
        try home.move(id: "black-1", toRoom: false)
        try home.move(id: "white-1", toRoom: false)
        room.sync(home)
        for tick in 50..<400 {
            let cats = room.step(dt: 0.1, now: Double(tick) * 0.1, width: 616)
            #expect(cats.count == 2)
            #expect(cats.allSatisfy { $0.x >= 48 && $0.x <= 568 })
        }
    }

    @Test func syncBeforeTheFirstFrameJustReplacesTheCats() {
        var room = CatRoom(household: household(1))
        room.sync(household(3))
        #expect(room.step(dt: 0.1, now: 0, width: 600).count == 3)
    }

    @Test func emptyRoomIsQuiet() {
        var room = CatRoom(household: CatHousehold(residents: []))
        #expect(room.step(dt: 0.1, now: 0, width: 600).isEmpty)
        #expect(room.pet(at: 0, point: RoomPoint(x: 100, y: 120), baseline: 170) == nil)
    }
}

struct CatCoatCatalogTests {
    /// The room draws any coat with the same clip names, so every coat must provide all of them.
    @Test func everyCoatProvidesTheSharedClips() throws {
        let url = resourcesURL.appendingPathComponent("CatArt/cat-assets.json")
        let catalog = try JSONDecoder().decode(CatAssetCatalog.self, from: Data(contentsOf: url))
        for coat in ["black", "white", "cheese", "tuxedo", "tabby", "split", "siamese", "cream", "foxfire", "norwegian", "sphynx"] { #expect(catalog.cats[coat] != nil) }
        let required: Set<String> = ["idle", "walkRight", "walkLeft", "groom", "pet"]
        for (coat, asset) in catalog.cats {
            #expect(required.isSubset(of: Set(asset.clips.keys)), "coat \(coat)")
            for name in asset.assetNames {
                #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent(name).path),
                        "coat \(coat) missing \(name)")
            }
        }
    }
}
