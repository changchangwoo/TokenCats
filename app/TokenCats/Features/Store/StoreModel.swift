import SwiftUI

/// Where the store is: its front page or the adoption box.
enum StoreRoute: Equatable {
    case main
    case adopt
}

/// The store's state on the main thread. Every change goes through `StoreService` on the churu queue,
/// then lands here for the room, the ledger and the store screen.
@MainActor
final class StoreModel: ObservableObject {
    static let shared = StoreModel()

    let catalog: StoreCatalog?
    /// Every price is 0 while testing: on by default in Debug builds, and switchable with
    /// `defaults write io.github.changchangwoo.tokencats storeFreeForTesting -bool YES|NO` (then relaunch).
    let isFreeForTesting: Bool
    @Published private(set) var household: CatHousehold
    @Published private(set) var inventory: StoreInventory
    @Published private(set) var busy = false
    @Published var route: StoreRoute = .main
    private let service: StoreService

    private init() {
        let sprites = CatSprites.shared
        let coats = sprites.coatNames
        let themes = RoomThemeCatalog.bundled
        isFreeForTesting = AppSettings.storeFreeForTesting
        let priced = StoreCatalog.bundled(coats: coats, themes: themes)
        catalog = isFreeForTesting ? priced?.freeForTesting() : priced
        service = StoreService(catalog: catalog, tracker: ChuruModel.shared.tracker,
                               catsFile: DataFiles.live.cats,
                               inventoryFile: DataFiles.live.inventory,
                               defaultBackground: themes.defaultID,
                               drawableCoats: Set(coats.filter { sprites.hasArt(coat: $0) }))
        household = service.household
        inventory = service.inventory
    }

    func theme(id: String) -> RoomTheme {
        RoomThemeSelection.theme(id: id, owned: inventory.ownedBackgrounds)
    }

    func purchase(_ product: StoreService.Product) async -> PurchaseResult {
        guard !busy else { return .failed }
        busy = true
        defer { busy = false }
        let service = service
        let outcome = await ChuruModel.shared.perform { service.purchase(product) }
        household = outcome.household
        inventory = outcome.inventory
        ChuruModel.shared.publish(outcome.snapshot)
        return outcome.result
    }

    /// Puts a prop up or takes it down, then lets the profile card catch up. False when it could not be saved.
    @discardableResult
    func setProp(_ prop: RoomProp, shown: Bool) async -> Bool {
        let service = service
        let saved = await ChuruModel.shared.perform { service.setProp(prop, shown: shown) }
        inventory = service.inventory
        Task { await ProfileSync.shared.syncIfDue() }
        return saved
    }

    /// Nil on success. A full room brings a stored cat in this way.
    func release(id: String) async -> CatHousehold.MoveError? {
        let service = service
        return apply(await ChuruModel.shared.perform { service.release(id: id) })
    }

    func swap(roomID: String, storedID: String) async -> CatHousehold.MoveError? {
        let service = service
        return apply(await ChuruModel.shared.perform { service.swap(roomID: roomID, storedID: storedID) })
    }

    private func apply(_ result: Result<CatHousehold, CatHousehold.MoveError>) -> CatHousehold.MoveError? {
        switch result {
        case .success(let next):
            household = next
            return nil
        case .failure(let error):
            return error
        }
    }

    /// Nil on success.
    func move(id: String, toRoom: Bool) async -> CatHousehold.MoveError? {
        let service = service
        let result = await ChuruModel.shared.perform { service.move(id: id, toRoom: toRoom) }
        switch result {
        case .success(let next):
            household = next
            return nil
        case .failure(let error):
            return error
        }
    }
}
