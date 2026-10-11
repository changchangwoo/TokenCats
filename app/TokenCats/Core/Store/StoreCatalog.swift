import Foundation

/// What the store sells and for how much. Prices and odds live in `store-catalog.json` so they can be
/// re-tuned without code; the catalog refuses a file that would sell something the app cannot show.
struct StoreCatalog: Equatable, Sendable {
    struct Tier: Codable, Equatable, Sendable {
        let id: String
        let name: LocalizedName
        let weight: Int
        let coats: [String]
    }

    struct CatBox: Codable, Equatable, Sendable {
        let price: Int
        let tiers: [Tier]
        /// The order the store's teaser shows the box's coats in, mixed across tiers. Optional; coats left out
        /// follow in tier order.
        var showcase: [String]?
    }

    struct BackgroundOffer: Codable, Equatable, Sendable {
        let id: String
        let price: Int
    }

    /// A prop for sale, by `RoomProp` raw value. Starter props are never sold.
    struct PropOffer: Codable, Equatable, Sendable {
        let id: String
        let price: Int
    }

    /// A tier's real chance once coats without art are left out, with the coats it can still give.
    struct BoxOdds: Equatable, Sendable {
        let tier: Tier
        let percent: Double

        /// One coat's chance: a drawn tier picks its coats evenly.
        var percentPerCoat: Double { tier.coats.isEmpty ? 0 : percent / Double(tier.coats.count) }
    }

    /// One opened box: the coat and the tier it came from.
    struct Draw: Equatable, Sendable {
        let coat: String
        let tier: Tier
    }

    enum Invalid: Error, Equatable {
        case schema, boxPrice, tierWeight, duplicateCoat, unknownCoat(String)
        case duplicateBackground, unknownBackground(String), freeBackground
        case duplicateProp, unknownProp(String), propPrice
    }

    let catBox: CatBox
    let backgrounds: [BackgroundOffer]
    let props: [PropOffer]

    /// `coats` are the coats in `cat-assets.json`; the background ids and default come from the room themes.
    init(data: Data, coats: Set<String>, backgroundIDs: Set<String>, defaultBackgroundID: String) throws {
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.schemaVersion == 1 else { throw Invalid.schema }
        guard manifest.catBox.price > 0 else { throw Invalid.boxPrice }
        guard manifest.catBox.tiers.allSatisfy({ $0.weight > 0 }) else { throw Invalid.tierWeight }
        let boxCoats = manifest.catBox.tiers.flatMap(\.coats)
        guard Set(boxCoats).count == boxCoats.count else { throw Invalid.duplicateCoat }
        if let unknown = boxCoats.first(where: { !coats.contains($0) }) { throw Invalid.unknownCoat(unknown) }
        let showcase = manifest.catBox.showcase ?? []
        guard Set(showcase).count == showcase.count else { throw Invalid.duplicateCoat }
        if let unknown = showcase.first(where: { !boxCoats.contains($0) }) { throw Invalid.unknownCoat(unknown) }
        let ids = manifest.backgrounds.map(\.id)
        guard Set(ids).count == ids.count else { throw Invalid.duplicateBackground }
        if let unknown = ids.first(where: { !backgroundIDs.contains($0) }) { throw Invalid.unknownBackground(unknown) }
        let free = manifest.backgrounds.filter { $0.price == 0 }
        guard free.count == 1, free[0].id == defaultBackgroundID,
              manifest.backgrounds.allSatisfy({ $0.price >= 0 }) else { throw Invalid.freeBackground }
        let props = manifest.props ?? []
        let propIDs = props.map(\.id)
        guard Set(propIDs).count == propIDs.count else { throw Invalid.duplicateProp }
        if let unknown = propIDs.first(where: { RoomProp(rawValue: $0).map(\.isStarter) ?? true }) {
            throw Invalid.unknownProp(unknown)
        }
        guard props.allSatisfy({ $0.price > 0 }) else { throw Invalid.propPrice }
        catBox = manifest.catBox
        backgrounds = manifest.backgrounds
        self.props = props
    }

    /// The same catalog with every price at zero, for trying the store without spending churu.
    func freeForTesting() -> StoreCatalog {
        StoreCatalog(catBox: CatBox(price: 0, tiers: catBox.tiers, showcase: catBox.showcase),
                     backgrounds: backgrounds.map { BackgroundOffer(id: $0.id, price: 0) },
                     props: props.map { PropOffer(id: $0.id, price: 0) })
    }

    private init(catBox: CatBox, backgrounds: [BackgroundOffer], props: [PropOffer]) {
        self.catBox = catBox
        self.backgrounds = backgrounds
        self.props = props
    }

    func price(ofBackground id: String) -> Int? {
        backgrounds.first { $0.id == id }?.price
    }

    func price(ofProp prop: RoomProp) -> Int? {
        props.first { $0.id == prop.rawValue }?.price
    }

    /// The coats the store's teaser shows around the box, at most `limit` (four a side): the catalog's showcase
    /// order first, then the box's other coats in tier order. Coats without art are skipped.
    func showcaseCoats(available: (String) -> Bool, limit: Int = 8) -> [String] {
        var shown: [String] = []
        for coat in (catBox.showcase ?? []) + catBox.tiers.flatMap(\.coats)
        where shown.count < limit && available(coat) && !shown.contains(coat) {
            shown.append(coat)
        }
        return shown
    }

    /// Props on sale, in the catalog's order.
    var propsForSale: [RoomProp] { props.compactMap { RoomProp(rawValue: $0.id) } }

    /// Picks a tier by weight, then one of its coats evenly. Coats that are not `available` (no art) are never
    /// drawn, and a tier left with none drops out of the weighting.
    func drawCat<G: RandomNumberGenerator>(available: (String) -> Bool, using generator: inout G) -> Draw? {
        let tiers = drawableTiers(available)
        let total = tiers.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 0..<total, using: &generator)
        for tier in tiers {
            if roll < tier.weight, let coat = tier.coats.randomElement(using: &generator) {
                return Draw(coat: coat, tier: tier)
            }
            roll -= tier.weight
        }
        return nil
    }

    /// The odds the store shows, matching `drawCat` exactly.
    func boxOdds(available: (String) -> Bool) -> [BoxOdds] {
        let tiers = drawableTiers(available)
        let total = Double(tiers.reduce(0) { $0 + $1.weight })
        return tiers.map { BoxOdds(tier: $0, percent: Double($0.weight) / total * 100) }
    }

    private func drawableTiers(_ available: (String) -> Bool) -> [Tier] {
        catBox.tiers.compactMap { tier -> Tier? in
            let coats = tier.coats.filter(available)
            return coats.isEmpty ? nil : Tier(id: tier.id, name: tier.name, weight: tier.weight, coats: coats)
        }
    }

    /// Every new household starts with the black cat: the cat TokenCats began with, on the app icon and in the
    /// first-run scene.
    static let firstCatCoat = "black"

    /// A new household's only cat: the black cat, or one of the first (most common) tier's coats without its art.
    func firstCoat<G: RandomNumberGenerator>(available: (String) -> Bool, using generator: inout G) -> String? {
        if available(Self.firstCatCoat) { return Self.firstCatCoat }
        return catBox.tiers.first?.coats.filter(available).randomElement(using: &generator)
    }

    /// The catalog shipped in the app, or nil when it is missing or invalid (the store then stays closed).
    static func bundled(coats: Set<String>, themes: RoomThemeCatalog = .bundled) -> StoreCatalog? {
        guard let url = Bundle.main.url(forResource: "store-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try StoreCatalog(data: data, coats: coats, backgroundIDs: Set(themes.backgrounds.map(\.id)),
                                    defaultBackgroundID: themes.defaultID)
        } catch {
            NSLog("[TokenCats] store-catalog.json rejected: \(error)")
            return nil
        }
    }
}

private struct Manifest: Decodable {
    let schemaVersion: Int
    let catBox: StoreCatalog.CatBox
    let backgrounds: [StoreCatalog.BackgroundOffer]
    let props: [StoreCatalog.PropOffer]?
}
