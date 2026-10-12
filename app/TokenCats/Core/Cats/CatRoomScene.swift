import Foundation

/// An sRGB colour shared by the notch canvas and the profile SVG.
struct SceneColor: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    var opacity: Double = 1

    var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }

    /// `amount` of the way from this colour to `other`, per channel, rounded.
    func mixed(with other: SceneColor, _ amount: Double) -> SceneColor {
        func channel(_ from: UInt8, _ to: UInt8) -> UInt8 {
            UInt8((Double(from) * (1 - amount) + Double(to) * amount).rounded())
        }
        return SceneColor(red: channel(red, other.red), green: channel(green, other.green),
                          blue: channel(blue, other.blue), opacity: opacity)
    }
}

/// A rectangle in room points.
struct SceneRect: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

/// A band across the whole room width.
struct SceneBand: Equatable, Sendable {
    let top: Double
    let height: Double
    let color: SceneColor
}

/// A rectangle on the calendar, in art pixels.
struct ScenePixelRect: Equatable, Sendable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let color: SceneColor
}

/// The wall calendar: a binding strip, paper, the month in pixel letters, then a 7 × 6 grid of 2×2 squares
/// for this month's days, with today outlined in the gap around its square.
struct CalendarProp: Equatable, Sendable {
    static let xFraction = 0.06
    /// Points per art pixel. Integer so the pixels stay sharp.
    static let pixel = 2.0
    static let artWidth = 24
    static let artHeight = 30
    private static let labelTop = 4
    private static let gridLeft = 2, gridTop = 11, cellSize = 2, cellPitch = 3

    let top: Double
    let rects: [ScenePixelRect]

    /// Left edge in points: 6% of the room width, snapped to the art pixel grid.
    func left(inWidth width: Double) -> Double {
        (width * Self.xFraction / Self.pixel).rounded() * Self.pixel
    }

    static let binding = SceneColor(red: 125, green: 99, blue: 89)
    static let paper = SceneColor(red: 244, green: 239, blue: 230)
    /// A day of this month with no record yet: before install or still to come.
    static let empty = SceneColor(red: 234, green: 228, blue: 216)
    static let levels = [
        SceneColor(red: 216, green: 208, blue: 191),
        SceneColor(red: 183, green: 217, blue: 154),
        SceneColor(red: 111, green: 179, blue: 90),
        SceneColor(red: 47, green: 125, blue: 59),
    ]

    /// English, fixed width, independent of the Mac's language so the profile looks the same everywhere.
    static let monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    /// 3 × 5 pixel letters for the month names; the shared set in `PixelGlyphs`.
    static let glyphs = PixelGlyphs.glyphs

    /// `nil` before the first churu count: binding and blank paper only.
    init(top: Double, calendar: ChuruMonthCalendar?) {
        self.top = top
        var rects = [
            ScenePixelRect(x: 0, y: 0, width: Self.artWidth, height: 2, color: Self.binding),
            ScenePixelRect(x: 0, y: 2, width: Self.artWidth, height: Self.artHeight - 2, color: Self.paper),
        ]
        guard let calendar else {
            self.rects = rects
            return
        }
        rects += Self.label(Self.monthNames[min(max(calendar.month, 1), 12) - 1])
        var today: (x: Int, y: Int)?
        for (index, day) in calendar.days.prefix(ChuruCalendar.rows * ChuruCalendar.daysPerWeek).enumerated() {
            let color: SceneColor
            switch day.state {
            case .outsideMonth: continue
            case .beforeInstall, .future: color = Self.empty
            case let .used(level): color = Self.levels[min(max(level, 0), Self.levels.count - 1)]
            }
            let x = Self.gridLeft + index % ChuruCalendar.daysPerWeek * Self.cellPitch
            let y = Self.gridTop + index / ChuruCalendar.daysPerWeek * Self.cellPitch
            rects.append(ScenePixelRect(x: x, y: y, width: Self.cellSize, height: Self.cellSize, color: color))
            if day.isToday { today = (x, y) }
        }
        if let today {
            let size = Self.cellSize
            rects += [
                ScenePixelRect(x: today.x - 1, y: today.y - 1, width: size + 2, height: 1, color: Self.binding),
                ScenePixelRect(x: today.x - 1, y: today.y + size, width: size + 2, height: 1, color: Self.binding),
                ScenePixelRect(x: today.x - 1, y: today.y, width: 1, height: size, color: Self.binding),
                ScenePixelRect(x: today.x + size, y: today.y, width: 1, height: size, color: Self.binding),
            ]
        }
        self.rects = rects
    }

    /// One rect per horizontal run of lit pixels, letters 1 pixel apart, centred on the sheet.
    private static func label(_ text: String) -> [ScenePixelRect] {
        let left = (artWidth - PixelGlyphs.width(of: text)) / 2
        return PixelGlyphs.rects(text, left: left, top: labelTop, color: binding)
    }
}

/// The soft shadow under the cats, inset from both walls.
struct FloorShadow: Equatable, Sendable {
    let inset: Double
    let top: Double
    let height: Double
    let color: SceneColor
}

/// A floor prop and where it stands in a room of a given width.
struct PlacedProp: Equatable, Sendable {
    let prop: RoomProp
    let rect: SceneRect
}

/// Everything in the cat room except the cats, drawn in this order: wall and floor fills, the background's
/// pictures, the floor's edge and trim, calendar, shadow, floor props.
/// The notch canvas and the profile SVG both draw this value, so the two rooms match.
struct CatRoomScene: Equatable, Sendable {
    static let floorHeight = 68.0
    /// The Home room's width: the 640pt open notch minus 12pt padding on each side (`HomeView`).
    /// The profile SVG replays the room at this width so it moves exactly like the notch.
    static let notchRoomWidth = 616.0
    /// Cats stand this far above the bottom edge.
    static let catFloorGap = 18.0

    /// Pictures are drawn between `bands[..<artLayer]` (fills) and `bands[artLayer...]` (floor edge and trim).
    static let artLayer = 2
    /// Picture size at 1x: the profile card's full width; the wall above the floor, the floor below.
    static let artWidth = 840.0
    static let wallArtHeight = 132.0

    let height: Double
    let bands: [SceneBand]
    let art: RoomArt?
    /// Where the calendar goes and what it shows; drawn only while it hangs in the room (`calendarProp`).
    let calendar: CalendarProp
    let showsCalendar: Bool
    var calendarProp: CalendarProp? { showsCalendar ? calendar : nil }
    let shadow: FloorShadow
    /// Placed props drawn from a picture, behind the cats.
    let props: [RoomProp]

    /// `props` are the props in the room; the calendar among them is drawn through `showsCalendar` instead.
    init(height: Double, calendarTop: Double, calendar: ChuruMonthCalendar?, theme: RoomTheme = .current,
         showsCalendar: Bool = true, props: [RoomProp] = []) {
        self.showsCalendar = showsCalendar
        self.props = props.filter { $0.art != nil && $0.slot.floorXFraction != nil }
        self.height = height
        art = theme.art
        let floorTop = height - Self.floorHeight
        bands = [
            SceneBand(top: 0, height: height, color: theme.wall),
            SceneBand(top: floorTop, height: Self.floorHeight, color: theme.floor),
            SceneBand(top: floorTop, height: 5, color: theme.floorEdge),
            SceneBand(top: floorTop + 5, height: 2, color: theme.floorHighlight),
        ]
        self.calendar = CalendarProp(top: calendarTop, calendar: calendar)
        shadow = FloorShadow(inset: 40, top: height - 24, height: 9,
                             color: SceneColor(red: 0, green: 0, blue: 0, opacity: 0.06))
    }

    /// Where the wall and floor pictures go in a room `width` wide: centred, the wall's bottom on the floor line,
    /// so a narrower or shorter room crops the sides and the top. Nil without pictures.
    func artRects(width: Double) -> (wall: SceneRect, floor: SceneRect)? {
        guard art != nil else { return nil }
        let x = (width - Self.artWidth) / 2, floorTop = height - Self.floorHeight
        return (SceneRect(x: x, y: floorTop - Self.wallArtHeight, width: Self.artWidth, height: Self.wallArtHeight),
                SceneRect(x: x, y: floorTop, width: Self.artWidth, height: Self.floorHeight))
    }

    /// Where each floor prop stands in a room `width` wide: its centre at the slot's share of the width, its bottom
    /// on the cats' floor, at its own size. Worked out at the room's real width (the notch's or the card's), never
    /// scaled, and snapped to whole points so the pixels stay sharp.
    func propRects(width: Double) -> [PlacedProp] {
        props.compactMap { prop in
            guard let art = prop.art, let fraction = prop.slot.floorXFraction else { return nil }
            let w = Double(art.width), h = Double(art.height)
            return PlacedProp(prop: prop, rect: SceneRect(x: (width * fraction - w / 2).rounded(),
                                                          y: height - Self.catFloorGap - h, width: w, height: h))
        }
    }

    /// Clear of the cats' heads in the 190pt Home room.
    static func notch(height: Double, calendar: ChuruMonthCalendar?) -> CatRoomScene {
        CatRoomScene(height: height, calendarTop: 12, calendar: calendar)
    }

    /// The room at the top of the profile card (`CatRoomSVG.roomHeight`).
    static func profile(calendar: ChuruMonthCalendar?, theme: RoomTheme = .current,
                        showsCalendar: Bool = true, props: [RoomProp] = []) -> CatRoomScene {
        CatRoomScene(height: 200, calendarTop: 8, calendar: calendar, theme: theme, showsCalendar: showsCalendar,
                     props: props)
    }
}
