import Testing
import Foundation
@testable import TokenCatsCore

struct RoomThemeTests {
    @Test(arguments: RoomTheme.all)
    func everyThemeKeepsItsGraphReadable(theme: RoomTheme) {
        #expect(theme.levels.count == 4)
        #expect(RoomTheme.contrast(theme.ink, theme.panel) >= 4.5)
        #expect(RoomTheme.contrast(theme.levels[0], theme.panel) >= 1.25)
        for step in 0..<3 {
            #expect(RoomTheme.contrast(theme.levels[step], theme.levels[step + 1]) >= 1.5)
        }
        #expect(RoomTheme.contrast(theme.levels[3], theme.panel) >= 3)
        #expect(RoomTheme.contrast(theme.stamp, theme.levels[3]) >= 3)
        #expect(theme.floorEdge == theme.panelEdge)
    }

    @Test func contrastFollowsWCAG() {
        let black = SceneColor(red: 0, green: 0, blue: 0), white = SceneColor(red: 255, green: 255, blue: 255)
        #expect(abs(RoomTheme.contrast(black, white) - 21) < 0.01)
        #expect(RoomTheme.contrast(white, white) == 1)
        #expect(RoomTheme.contrast(black, white) == RoomTheme.contrast(white, black))
    }

    @Test func cozyTakesItsColoursFromThePictures() {
        let cozy = RoomTheme.cozy
        #expect(RoomTheme.current == cozy)
        #expect(cozy.wall == SceneColor(red: 238, green: 226, blue: 212))
        #expect(cozy.floor == SceneColor(red: 202, green: 166, blue: 136))
        #expect(cozy.floorEdge == SceneColor(red: 125, green: 99, blue: 89))
        #expect(cozy.floorHighlight == SceneColor(red: 213, green: 184, blue: 160))
        #expect(cozy.art == RoomArt(wall: "room-cozy-wall", floor: "room-cozy-floor"))
    }

    @Test func derivesHighlightsAndLevelsFromPrimaries() {
        let colors = RoomColors(wall: rgb(238, 226, 212), floor: rgb(202, 166, 136), edge: rgb(125, 99, 89),
                                panel: rgb(122, 98, 82), ink: rgb(244, 239, 230), accent: rgb(217, 245, 154),
                                stamp: rgb(84, 116, 52))
        let theme = RoomTheme(id: "t", colors: colors)
        #expect(theme.floorEdge == colors.edge)
        #expect(theme.panelEdge == colors.edge)
        #expect(theme.floorHighlight == colors.floor.mixed(with: rgb(255, 255, 255), 0.2))
        #expect(theme.panelHighlight == colors.panel.mixed(with: colors.ink, 0.3))
        #expect(theme.levels == [colors.panel.mixed(with: rgb(0, 0, 0), 0.15),
                                 colors.panel.mixed(with: colors.accent, 0.45),
                                 colors.panel.mixed(with: colors.accent, 0.7), colors.accent])
        #expect(theme.art == nil)
        #expect(rgb(100, 0, 200).mixed(with: rgb(200, 255, 0), 0.5) == rgb(150, 128, 100))
    }

    @Test func roleColoursComeFromThePrimaries() {
        let cozy = RoomTheme.cozy
        #expect(cozy.surface == cozy.panel.mixed(with: rgb(0, 0, 0), 0.15))
        #expect(cozy.preview == cozy.wall.mixed(with: cozy.panel, 0.15))
        #expect(cozy.previewInk == cozy.surface)
    }

    @Test func everyBundledBackgroundReadsOnItsSurfaces() throws {
        let url = resourcesURL.appendingPathComponent("room-themes.json")
        for theme in try RoomThemeCatalog(data: Data(contentsOf: url)).backgrounds.map(\.theme) {
            #expect(RoomTheme.contrast(theme.ink, theme.panel) >= 4.5, "\(theme.id) text on base")
            #expect(RoomTheme.contrast(theme.ink, theme.surface) >= 4.5, "\(theme.id) text on surface")
            #expect(RoomTheme.contrast(theme.previewInk, theme.preview) >= 4.5, "\(theme.id) text on preview")
        }
    }

    @Test func explicitLevelsWin() {
        let colors = plainTheme.colors
        let levels = [rgb(1, 1, 1), rgb(2, 2, 2), rgb(3, 3, 3), rgb(4, 4, 4)]
        #expect(RoomTheme(id: "t", colors: colors, levels: levels).levels == levels)
    }

    @Test func bundledArtFilesExist() throws {
        let resources = resourcesURL
        let catalog = try RoomThemeCatalog(data: Data(contentsOf: resources.appendingPathComponent("room-themes.json")))
        #expect(catalog.selected(id: "cozy").art != nil)
        for art in catalog.backgrounds.compactMap(\.theme.art) {
            for name in [art.wall, art.floor] {
                for file in ["\(name).png", "\(name)@2x.png"] {
                    #expect(FileManager.default.fileExists(
                        atPath: resources.appendingPathComponent("RoomArt/\(file)").path), "\(file)")
                }
            }
        }
    }

    @Test func sceneTakesItsColoursFromTheTheme() {
        let scene = CatRoomScene(height: 190, calendarTop: 12, calendar: nil, theme: plainTheme)
        #expect(scene.bands.map(\.color) == [plainTheme.wall, plainTheme.floor,
                                             plainTheme.floorEdge, plainTheme.floorHighlight])
    }

    @Test func choosingBackgroundChangesWallpaperFloorAndLedgerTogether() throws {
                let url = resourcesURL.appendingPathComponent("room-themes.json")
        let catalog = try RoomThemeCatalog(data: Data(contentsOf: url))
        let cozy = catalog.selected(id: "cozy")
        let pool = catalog.selected(id: "night")
        #expect(catalog.defaultID == "cozy")
        #expect(cozy.wall != pool.wall)
        #expect(cozy.floor != pool.floor)
        #expect(cozy.panel != pool.panel)
        let scene = CatRoomScene(height: 190, calendarTop: 12, calendar: nil, theme: pool)
        #expect(scene.bands[0].color == pool.wall)
        #expect(scene.bands[1].color == pool.floor)
    }

    @Test func missingBackgroundFallsBackAsOneSet() throws {
                let url = resourcesURL.appendingPathComponent("room-themes.json")
        let catalog = try RoomThemeCatalog(data: Data(contentsOf: url))
        #expect(catalog.selected(id: "removed-pack") == catalog.selected(id: catalog.defaultID))
    }

    @Test func persistedBackgroundChoiceResolvesOneTheme() throws {
        let url = resourcesURL.appendingPathComponent("room-themes.json")
        let catalog = try RoomThemeCatalog(data: Data(contentsOf: url))
        let suite = "room-theme-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("night", forKey: RoomThemeSelection.key)
        #expect(RoomThemeSelection.selected(catalog: catalog, defaults: defaults, owned: ["cozy", "night"])
                == catalog.selected(id: "night"))
    }

    @Test func unownedChoiceFallsBackToTheDefault() throws {
        let url = resourcesURL.appendingPathComponent("room-themes.json")
        let catalog = try RoomThemeCatalog(data: Data(contentsOf: url))
        #expect(RoomThemeSelection.theme(id: "night", owned: ["cozy"], catalog: catalog) == catalog.selected(id: "cozy"))
        #expect(RoomThemeSelection.theme(id: nil, owned: ["cozy"], catalog: catalog) == catalog.selected(id: "cozy"))
    }

    @Test func everyBundledBackgroundKeepsItsGraphReadable() throws {
        let url = resourcesURL.appendingPathComponent("room-themes.json")
        let catalog = try RoomThemeCatalog(data: Data(contentsOf: url))
        #expect(Set(catalog.backgrounds.map(\.id)) == ["cozy", "night", "sakura", "forest", "halloween"])
        for theme in catalog.backgrounds.map(\.theme) {
            #expect(RoomTheme.contrast(theme.levels[0], theme.panel) >= 1.25, "\(theme.id)")
            for step in 0..<3 {
                #expect(RoomTheme.contrast(theme.levels[step], theme.levels[step + 1]) >= 1.5, "\(theme.id)")
            }
            #expect(RoomTheme.contrast(theme.levels[3], theme.panel) >= 3, "\(theme.id)")
            #expect(RoomTheme.contrast(theme.stamp, theme.levels[3]) >= 3, "\(theme.id)")
        }
    }
}

private func rgb(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> SceneColor {
    SceneColor(red: red, green: green, blue: blue)
}
