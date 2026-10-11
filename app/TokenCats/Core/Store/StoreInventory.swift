import Foundation

/// One purchase, kept for the record. `result` is the adopted cat's id, or the background's or prop's id.
struct StorePurchase: Codable, Equatable, Sendable {
    let at: Date
    let product: String
    let price: Int
    let result: String
}

/// What the user has bought besides cats (cats live in `cats.json`). The free default background and the calendar
/// are always owned.
struct StoreInventory: Codable, Equatable, Sendable {
    private(set) var ownedBackgrounds: Set<String>
    /// Bought props by raw value; starter props are not listed.
    private(set) var ownedProps: Set<String> = []
    private(set) var purchases: [StorePurchase] = []
    /// Props put up in the room.
    private(set) var decor: RoomDecor = .starter

    init(defaultBackground: String) {
        ownedBackgrounds = [defaultBackground]
    }

    /// Files from before props existed have no `decor`: their room had the calendar up. Files from before props
    /// were sold have no `ownedProps`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ownedBackgrounds = try container.decode(Set<String>.self, forKey: .ownedBackgrounds)
        purchases = try container.decodeIfPresent([StorePurchase].self, forKey: .purchases) ?? []
        decor = try container.decodeIfPresent(RoomDecor.self, forKey: .decor) ?? .starter
        ownedProps = try container.decodeIfPresent(Set<String>.self, forKey: .ownedProps) ?? []
    }

    mutating func set(_ prop: RoomProp, shown: Bool) { decor.set(prop, shown: shown) }

    func owns(background id: String) -> Bool { ownedBackgrounds.contains(id) }

    mutating func own(background id: String) { ownedBackgrounds.insert(id) }

    func owns(prop: RoomProp) -> Bool { prop.isStarter || ownedProps.contains(prop.rawValue) }

    mutating func own(prop: RoomProp) { ownedProps.insert(prop.rawValue) }

    mutating func record(_ purchase: StorePurchase) { purchases.append(purchase) }

    static func load(from file: JSONFile<StoreInventory>, defaultBackground: String) -> StoreInventory {
        var inventory = file.load() ?? StoreInventory(defaultBackground: defaultBackground)
        inventory.ownedBackgrounds.insert(defaultBackground)
        return inventory
    }
}
