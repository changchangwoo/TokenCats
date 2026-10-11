import Foundation

/// Pictures for one background, by bundle image name (`RoomArt/<name>.png` and `@2x`). The wall is 840×132 and the
/// floor 840×68 at 1x; narrower rooms show the middle.
struct RoomArt: Codable, Equatable, Sendable {
    let wall: String
    let floor: String
}

/// The colours a background's author picks; everything else is worked out from them.
struct RoomColors: Equatable, Sendable {
    /// Wall and floor fills, shown where there is no picture (and in store previews).
    let wall: SceneColor
    let floor: SceneColor
    /// The dark line across the top of the floor and of the panel below the room.
    let edge: SceneColor
    /// The panel under the room (ledger, dashboard, the profile card's graph area).
    let panel: SceneColor
    /// Text on `panel`.
    let ink: SceneColor
    /// The graph's busiest level and other highlights.
    let accent: SceneColor
    /// The paw stamped inside busiest-level squares.
    let stamp: SceneColor
}

/// One room background: its pictures and the colours every other screen takes from it. The notch room and the
/// profile card draw from the same theme, so a new background brings its own wall and floor and a graph that still
/// reads on top of them.
struct RoomTheme: Equatable, Sendable, CustomStringConvertible {
    let id: String
    let colors: RoomColors
    let art: RoomArt?
    let floorHighlight: SceneColor
    let panelHighlight: SceneColor
    /// Graph levels 0…3; level 3 squares carry a paw stamp.
    let levels: [SceneColor]

    var wall: SceneColor { colors.wall }
    var floor: SceneColor { colors.floor }
    var floorEdge: SceneColor { colors.edge }
    var panel: SceneColor { colors.panel }
    var panelEdge: SceneColor { colors.edge }
    var ink: SceneColor { colors.ink }
    var stamp: SceneColor { colors.stamp }

    // Roles every screen uses, whatever the palette: the base is the panel; cards sit a step darker; cats and
    // rooms appear on a light preview surface.
    var surface: SceneColor { colors.panel.mixed(with: SceneColor(red: 0, green: 0, blue: 0), 0.15) }
    var preview: SceneColor { colors.wall.mixed(with: colors.panel, 0.15) }
    var accent: SceneColor { colors.accent }
    /// Text on `preview`: the darker surface or the light ink, whichever reads better.
    var previewInk: SceneColor {
        RoomTheme.contrast(surface, preview) >= RoomTheme.contrast(ink, preview) ? surface : ink
    }
    var description: String { id }

    /// Highlights and graph levels come from the primaries unless `levels` overrides the graph.
    init(id: String, colors: RoomColors, levels: [SceneColor]? = nil, art: RoomArt? = nil) {
        self.id = id
        self.colors = colors
        self.art = art
        floorHighlight = colors.floor.mixed(with: SceneColor(red: 255, green: 255, blue: 255), 0.2)
        panelHighlight = colors.panel.mixed(with: colors.ink, 0.3)
        self.levels = levels ?? [colors.panel.mixed(with: SceneColor(red: 0, green: 0, blue: 0), 0.15),
                                 colors.panel.mixed(with: colors.accent, 0.45),
                                 colors.panel.mixed(with: colors.accent, 0.7),
                                 colors.accent]
    }

    /// Wallpaper and wooden floor pictures; the ledger keeps the original brown and green.
    static let cozy = RoomTheme(
        id: "cozy",
        colors: RoomColors(wall: rgb(238, 226, 212), floor: rgb(202, 166, 136), edge: rgb(125, 99, 89),
                           panel: rgb(122, 98, 82), ink: rgb(244, 239, 230), accent: rgb(217, 245, 154),
                           stamp: rgb(84, 116, 52)),
        levels: [rgb(102, 81, 67), rgb(110, 154, 85), rgb(151, 199, 109), rgb(217, 245, 154)],
        art: RoomArt(wall: "room-cozy-wall", floor: "room-cozy-floor"))

    static let all = [cozy]

    /// Stable fallback for callers that do not pass a theme. The user's choice comes from RoomThemeSelection.
    static let current = cozy

    /// WCAG contrast ratio of two colours, 1…21.
    static func contrast(_ first: SceneColor, _ second: SceneColor) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ color: SceneColor) -> Double {
        func channel(_ value: UInt8) -> Double {
            let v = Double(value) / 255
            return v <= 0.039_28 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }

    private static func rgb(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> SceneColor {
        SceneColor(red: red, green: green, blue: blue)
    }
}
