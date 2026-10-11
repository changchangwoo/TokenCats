import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Turns the cats and the year into the profile SVG, and writes it for "프로필 SVG 만들기".
@MainActor
enum ProfileExport {
    static var fileURL: URL {
        AppPaths.supportDirectory
            .appendingPathComponent("profile", isDirectory: true)
            .appendingPathComponent("catroom.svg")
    }

    /// Same residents, in the same order, as the notch room (coats without art are left out there too).
    /// Throws `CatRoomSVG.TooLarge` instead of making a card over the 2MB budget.
    static func svg(calendar: ChuruMonthCalendar, year: ContributionYear?, showsNumbers: Bool,
                    owner: String?, updated: Date,
                    theme override: RoomTheme? = nil) throws -> String {
        let sprites = CatSprites.shared
        let store = StoreModel.shared
        let residents = store.household.roomResidents.filter { sprites.hasArt(coat: $0.coat) }
        var frames: [String: CatCoatFrames] = [:]
        for coat in Set(residents.map(\.coat)) {
            guard let idle = pngs(clip: "idle", coat: coat).first else { continue }
            frames[coat] = CatCoatFrames(idle: idle, groom: pngs(clip: "groom", coat: coat),
                                         walkRight: pngs(clip: "walkRight", coat: coat),
                                         walkLeft: pngs(clip: "walkLeft", coat: coat))
        }
        let theme = override ?? RoomThemeSelection.selected(owned: store.inventory.ownedBackgrounds)
        let props = store.inventory.decor.shownProps
        return try CatRoomSVG.checkedRender(calendar: calendar,
                                            cats: residents.map { CatRoomSVGCat(id: $0.id, coat: $0.coat) },
                                            frames: frames, year: year, showsNumbers: showsNumbers,
                                            owner: owner, updated: updated,
                                            theme: theme, art: RoomArtImages.pngs(for: theme.art),
                                            showsCalendar: store.inventory.decor.shows(.calendar),
                                            props: props, propArt: RoomArtImages.pngs(for: props))
    }

    static func write(_ svg: String) throws -> URL {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(svg.utf8).write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func pngs(clip: String, coat: String) -> [Data] {
        let sprites = CatSprites.shared
        return (0..<sprites.clipLength(clip, coat: coat)).compactMap { index in
            sprites.frame(clip: clip, index: index, coat: coat).flatMap(png)
        }
    }

    private static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
