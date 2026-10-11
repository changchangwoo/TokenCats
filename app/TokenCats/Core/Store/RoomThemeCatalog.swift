import Foundation

/// A background is one asset: wallpaper, floor, and ledger always share the same ID.
struct RoomThemeCatalog: Sendable {
    struct Background: Sendable {
        let id: String
        let name: LocalizedName
        let theme: RoomTheme
    }

    enum InvalidAsset: Error {
        case schema, duplicateID, missingDefault, incompletePalette
    }

    let defaultID: String
    let backgrounds: [Background]

    init(data: Data) throws {
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.schemaVersion == 2 else { throw InvalidAsset.schema }
        let backgrounds = manifest.backgrounds.map { asset in
            Background(id: asset.id, name: asset.name, theme: asset.theme)
        }
        guard Set(backgrounds.map(\.id)).count == backgrounds.count else { throw InvalidAsset.duplicateID }
        guard backgrounds.contains(where: { $0.id == manifest.defaultID }) else { throw InvalidAsset.missingDefault }
        guard backgrounds.allSatisfy({ $0.theme.levels.count == 4 &&
                                      $0.theme.art.map { !$0.wall.isEmpty && !$0.floor.isEmpty } ?? true &&
                                      RoomTheme.contrast($0.theme.ink, $0.theme.panel) >= 4.5 })
        else { throw InvalidAsset.incompletePalette }
        defaultID = manifest.defaultID
        self.backgrounds = backgrounds
    }

    func selected(id: String?) -> RoomTheme {
        backgrounds.first(where: { $0.id == id })?.theme
            ?? backgrounds.first(where: { $0.id == defaultID })!.theme
    }

    /// The backgrounds shipped in the app; the two built-in themes stand in if the file is missing or invalid.
    static let bundled: RoomThemeCatalog = {
        guard let url = Bundle.main.url(forResource: "room-themes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? RoomThemeCatalog(data: data) else {
            return RoomThemeCatalog(defaultID: "cozy", backgrounds: [
                Background(id: "cozy", name: LocalizedName(["en": "Cozy room"]), theme: .cozy),
            ])
        }
        return catalog
    }()

    private init(defaultID: String, backgrounds: [Background]) {
        self.defaultID = defaultID
        self.backgrounds = backgrounds
    }
}

/// Single persisted background choice, shared by the notch room and profile export.
/// A choice the user does not own (or no choice) resolves to the free default.
enum RoomThemeSelection {
    static let key = "roomThemeID"

    static func theme(id: String?, owned: Set<String>, catalog: RoomThemeCatalog = .bundled) -> RoomTheme {
        catalog.selected(id: id.flatMap { owned.contains($0) ? $0 : nil })
    }

    static func selected(catalog: RoomThemeCatalog = .bundled, defaults: UserDefaults = .standard,
                         owned: Set<String>) -> RoomTheme {
        theme(id: defaults.string(forKey: key), owned: owned, catalog: catalog)
    }
}

private struct Manifest: Decodable {
    let schemaVersion: Int
    let defaultID: String
    let backgrounds: [BackgroundAsset]
}

private struct BackgroundAsset: Decodable {
    let id: String
    let name: LocalizedName
    let art: RoomArt?
    let colors: ColorsAsset
    let levels: [SceneColor]?

    var theme: RoomTheme {
        RoomTheme(id: id, colors: RoomColors(wall: colors.wall, floor: colors.floor, edge: colors.edge,
                                             panel: colors.panel, ink: colors.ink, accent: colors.accent,
                                             stamp: colors.stamp),
                  levels: levels, art: art)
    }
}

private struct ColorsAsset: Decodable {
    let wall: SceneColor
    let floor: SceneColor
    let edge: SceneColor
    let panel: SceneColor
    let ink: SceneColor
    let accent: SceneColor
    let stamp: SceneColor
}

extension SceneColor: Decodable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard value.count == 7, value.first == "#",
              let rgb = UInt32(value.dropFirst(), radix: 16) else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(),
                                                   debugDescription: "Expected #RRGGBB colour")
        }
        self.init(red: UInt8((rgb >> 16) & 0xFF), green: UInt8((rgb >> 8) & 0xFF), blue: UInt8(rgb & 0xFF))
    }
}
