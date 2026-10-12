import Foundation

enum PurchaseResult: Equatable, Sendable {
    /// `cat.inRoom` tells whether it went to the room or to storage.
    case adopted(CatResidentRecord, tier: StoreCatalog.Tier)
    case backgroundOwned(String)
    case propOwned(RoomProp)
    /// Churu given to a cat; `level` is its bond level afterwards.
    case treated(catID: String, level: Int)
    case insufficient(short: Int)
    /// Nothing left to buy: a background or prop already owned, or a treat for a cat already at the last level.
    case alreadyOwned
    case failed
}

/// A purchase's result with the state the UI should show afterwards.
struct StoreOutcome: Sendable {
    let result: PurchaseResult
    let snapshot: ChuruSnapshot
    let household: CatHousehold
    let inventory: StoreInventory
    let bonds: CatBondBook
}

/// Buys from the store and moves cats between the room and storage; the only writer of `cats.json` and
/// `inventory.json`. Treats credit the cat's bond through `CatBondService` on the same queue. Not thread-safe: run
/// it on the churu tracker's queue, so a purchase always checks the balance the tracker has just computed rather
/// than a number on screen.
final class StoreService: @unchecked Sendable {
    enum Product: Equatable, Sendable {
        case catBox
        case background(String)
        case prop(RoomProp)
        /// Churu for one cat, by id; the cat may be in the room or in storage.
        case treat(catID: String)
    }

    let catalog: StoreCatalog?
    private(set) var household: CatHousehold
    private(set) var inventory: StoreInventory
    var bondBook: CatBondBook { bonds.book }
    private let tracker: ChuruTracker
    private let bonds: CatBondService
    private let catsFile: JSONFile<CatHousehold>
    private let inventoryFile: JSONFile<StoreInventory>
    private let drawableCoats: Set<String>
    private var generator: SeededGenerator

    init(catalog: StoreCatalog?, tracker: ChuruTracker, bonds: CatBondService, catsFile: JSONFile<CatHousehold>,
         inventoryFile: JSONFile<StoreInventory>, defaultBackground: String, drawableCoats: Set<String>,
         seed: UInt64 = UInt64.random(in: .min ... .max)) {
        self.catalog = catalog
        self.tracker = tracker
        self.bonds = bonds
        self.catsFile = catsFile
        self.inventoryFile = inventoryFile
        self.drawableCoats = drawableCoats
        var generator = SeededGenerator(seed: seed)
        household = CatHousehold.load(from: catsFile) {
            catalog?.firstCoat(available: drawableCoats.contains, using: &generator)
                ?? drawableCoats.sorted().first ?? "black"
        }
        self.generator = generator
        inventory = StoreInventory.load(from: inventoryFile, defaultBackground: defaultBackground)
    }

    /// Recompute the balance, check it, save what was bought, then spend. A crash between the last two steps
    /// leaves a free item rather than churu spent on nothing.
    func purchase(_ product: Product, now: Date = Date()) -> StoreOutcome {
        let snapshot = tracker.refresh(now: now)
        func outcome(_ result: PurchaseResult, _ snapshot: ChuruSnapshot) -> StoreOutcome {
            StoreOutcome(result: result, snapshot: snapshot, household: household, inventory: inventory,
                         bonds: bonds.book)
        }
        guard let catalog else { return outcome(.failed, snapshot) }

        let price: Int
        switch product {
        case .catBox:
            price = catalog.catBox.price
        case .background(let id):
            guard let offer = catalog.price(ofBackground: id) else { return outcome(.failed, snapshot) }
            guard !inventory.owns(background: id) else { return outcome(.alreadyOwned, snapshot) }
            price = offer
        case .prop(let prop):
            guard let offer = catalog.price(ofProp: prop) else { return outcome(.failed, snapshot) }
            guard !inventory.owns(prop: prop) else { return outcome(.alreadyOwned, snapshot) }
            price = offer
        case .treat(let catID):
            guard let offer = catalog.treatPrice else { return outcome(.failed, snapshot) }
            guard household.residents.contains(where: { $0.id == catID }) else { return outcome(.failed, snapshot) }
            // A cat at Lv.99 gains nothing, so no churu is taken for it.
            guard bonds.book.level(of: catID) < CatBondRules.maxLevel else { return outcome(.alreadyOwned, snapshot) }
            price = offer
        }
        guard snapshot.balance >= price else { return outcome(.insufficient(short: price - snapshot.balance), snapshot) }

        var nextHousehold = household
        var nextInventory = inventory
        var result: PurchaseResult
        switch product {
        case .catBox:
            guard let draw = catalog.drawCat(available: drawableCoats.contains, using: &generator) else {
                return outcome(.failed, snapshot)
            }
            let cat = nextHousehold.adopt(coat: draw.coat)
            nextInventory.record(StorePurchase(at: now, product: "catBox", price: price, result: cat.id))
            result = .adopted(cat, tier: draw.tier)
            guard catsFile.save(nextHousehold) else { return outcome(.failed, snapshot) }
        case .background(let id):
            nextInventory.own(background: id)
            nextInventory.record(StorePurchase(at: now, product: "background", price: price, result: id))
            result = .backgroundOwned(id)
        case .prop(let prop):
            nextInventory.own(prop: prop)
            nextInventory.record(StorePurchase(at: now, product: "prop", price: price, result: prop.rawValue))
            result = .propOwned(prop)
        case .treat(let catID):
            nextInventory.record(StorePurchase(at: now, product: "treat", price: price, result: catID))
            result = .treated(catID: catID, level: bonds.book.level(of: catID))
        }
        household = nextHousehold
        guard inventoryFile.save(nextInventory) else {
            // A cat already saved stays adopted; a background, prop or treat is not owned until its record is written.
            return outcome(product == .catBox ? result : .failed, snapshot)
        }
        inventory = nextInventory
        if case .treat(let catID) = product {
            // Credited only once the purchase is on record, so a crash leaves a recorded treat, never a free one.
            result = .treated(catID: catID, level: bonds.treat(catID).level(of: catID))
        }
        guard tracker.spend(price, balance: snapshot.balance) else { return outcome(result, snapshot) }
        return outcome(result, snapshot.spending(price))
    }

    func move(id: String, toRoom: Bool) -> Result<CatHousehold, CatHousehold.MoveError> {
        change { try $0.move(id: id, toRoom: toRoom) }
    }

    /// Puts a prop up or takes it down; false for a prop not owned or when the change could not be saved.
    func setProp(_ prop: RoomProp, shown: Bool) -> Bool {
        guard !shown || inventory.owns(prop: prop) else { return false }
        var next = inventory
        next.set(prop, shown: shown)
        guard next != inventory else { return true }
        guard inventoryFile.save(next) else { return false }
        inventory = next
        return true
    }

    /// Names a cat (a blank name takes the coat name back).
    func rename(id: String, to name: String) -> Result<CatHousehold, CatHousehold.MoveError> {
        change { try $0.rename(id: id, to: name) }
    }

    /// Releases a cat for good; the churu spent on it stays spent and its bond is forgotten.
    func release(id: String) -> Result<CatHousehold, CatHousehold.MoveError> {
        let result = change { try $0.release(id: id) }
        if case .success = result { bonds.forget(id) }
        return result
    }

    func swap(roomID: String, storedID: String) -> Result<CatHousehold, CatHousehold.MoveError> {
        change { try $0.swap(roomID: roomID, storedID: storedID) }
    }

    /// Applies a room change and saves it; nothing changes unless the file is written.
    private func change(_ edit: (inout CatHousehold) throws -> Void) -> Result<CatHousehold, CatHousehold.MoveError> {
        var next = household
        do {
            try edit(&next)
        } catch let error as CatHousehold.MoveError {
            return .failure(error)
        } catch {
            return .failure(.unknownCat)
        }
        guard next != household else { return .success(household) }
        guard catsFile.save(next) else { return .failure(.saveFailed) }
        household = next
        return .success(next)
    }
}
