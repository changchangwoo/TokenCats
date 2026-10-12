import Foundation

/// One cat in the profile SVG. Cats whose coat has no frames are left out.
struct CatRoomSVGCat: Equatable, Sendable {
    let id: String
    let coat: String
    /// Bond level, drawn as a pixel tag under the cat.
    let level: Int

    init(id: String, coat: String, level: Int = 1) {
        self.id = id
        self.coat = coat
        self.level = level
    }
}

/// PNG bytes for one coat: the sitting pose and the grooming and walking clips in playback order.
/// Without walk frames the cat sits where it starts.
struct CatCoatFrames: Equatable, Sendable {
    let idle: Data
    let groom: [Data]
    let walkRight: [Data]
    let walkLeft: [Data]
}

/// One moment of one cat in the replayed notch room.
struct CatSample: Equatable, Sendable {
    let x: Double
    let yOffset: Double
    /// `i0` sitting, `g0…` grooming, `r0…`/`l0…` walking right/left.
    let pose: String
}

/// Everything one cat did during the replay, one sample per tick.
struct CatTrack: Equatable, Sendable {
    let id: String
    let coat: String
    let level: Int
    var samples: [CatSample]
}

/// The cat room as one self-contained SVG for a GitHub profile README.
///
/// No viewBox or outer size, so `<img width="100%" height="160">` sizes it (checked on a throwaway
/// profile repo). The profile does not walk: each cat sits where the notch room (`CatRoom`)
/// first places it, drawn in % of the README width. Grooming follows the notch room's own rhythm, taken from a
/// replay of the room; the moments a cat would be walking show it sitting instead.
/// The room carries no text elements, day numbers or token counts; the wall calendar's month is pixel letters.
/// The optional year panel is the one place with text: month names, a legend and, when shown, token numbers.
enum CatRoomSVG {
    /// The card: a fixed 840 × 472 drawing (200 room + 272 numbers and graph), so GitHub's `height: auto` keeps it
    /// whole and the README width scales all of it.
    static let cardWidth = 840.0
    static let roomHeight = 200.0
    static let cardHeight = 504.0
    static let catSize = 96
    /// Top of the level tag's letters in the cat's own coordinates: 96 pixels of cat, then the floor gap (18) minus
    /// the letters' 10 pixels, 2 of plaque and a 4-pixel breath above the room's bottom edge.
    static let levelTagTop = catSize + Int(CatRoomScene.catFloorGap) - 16
    /// Five coats with sitting and grooming frames come to about 0.9MB; the cap leaves room for more coats.
    static let maxBytes = 2_000_000
    /// The profile room holds at most five cats.
    /// The profile room shows the same cats as the notch room.
    static let maxCats = CatHousehold.roomCapacity
    /// The room is replayed at the notch room's own width and scaled to the card, so the cats sit where they
    /// sit in the notch.
    static let simulationWidth = CatRoomScene.notchRoomWidth
    /// One loop of the profile animation.
    static let simulationSeconds = 150.0
    private static let tick = 1.0 / 12.0
    private static var scale: Double { cardWidth / simulationWidth }

    /// Thrown by `checkedRender` when the file would be over `maxBytes`.
    struct TooLarge: Error, Equatable {
        let bytes: Int
    }

    /// `render`, refusing output over the 2MB budget instead of writing a file GitHub may not show.
    static func checkedRender(calendar: ChuruMonthCalendar?, cats: [CatRoomSVGCat], frames: [String: CatCoatFrames],
                              year: ContributionYear? = nil, showsNumbers: Bool = false, owner: String? = nil,
                              updated: Date? = nil, theme: RoomTheme = .current,
                              art: RoomArtPNGs? = nil, showsCalendar: Bool = true,
                              props: [RoomProp] = [], propArt: [String: Data] = [:],
                              showsLevels: Bool = false) throws -> String {
        let svg = render(calendar: calendar, cats: cats, frames: frames, year: year, showsNumbers: showsNumbers,
                         owner: owner, updated: updated, theme: theme, art: art, showsCalendar: showsCalendar,
                         props: props, propArt: propArt, showsLevels: showsLevels)
        let bytes = svg.utf8.count
        if bytes > maxBytes { throw TooLarge(bytes: bytes) }
        return svg
    }

    /// The profile card. With `year` the graph continues the floor below the room; its numbers show only with
    /// `showsNumbers`. `owner` and `updated` fill the footer. `art` holds the theme's 1x wall and floor pictures;
    /// without it (or for a theme without pictures) the wall and floor stay plain colour. `props` stand on the floor
    /// with their 1x pictures from `propArt` (by image name); a prop without one is left out.
    static func render(calendar: ChuruMonthCalendar?, cats: [CatRoomSVGCat], frames: [String: CatCoatFrames],
                       year: ContributionYear? = nil, showsNumbers: Bool = false, owner: String? = nil,
                       updated: Date? = nil, theme: RoomTheme = .current, art: RoomArtPNGs? = nil,
                       showsCalendar: Bool = true, props: [RoomProp] = [], propArt: [String: Data] = [:],
                       showsLevels: Bool = false, calendarSystem: Calendar = .current) -> String {
        let scene = CatRoomScene.profile(calendar: calendar, theme: theme, showsCalendar: showsCalendar, props: props)
        let drawn = Array(cats.filter { frames[$0.coat].map { !$0.idle.isEmpty } ?? false }.prefix(maxCats))
        var coats: [String] = []
        for cat in drawn where !coats.contains(cat.coat) { coats.append(cat.coat) }
        let height = year == nil ? roomHeight : cardHeight
        let size = #"width="\#(number(cardWidth))" height="\#(number(height))""#

        var out = #"<svg xmlns="http://www.w3.org/2000/svg" \#(size) viewBox="0 0 \#(number(cardWidth)) \#(number(height))">"#
        var style = "image{image-rendering:pixelated}"
        if year != nil {
            style += #"@font-face{font-family:"\#(CardFont.family)";font-weight:400 800;"#
                + #"src:url(data:font/woff2;base64,\#(CardFont.woff2Base64)) format("woff2")}"#
        }
        out += "<style>\(style)</style>"
        out += "<defs>"
        out += #"<clipPath id="card"><rect \#(size) rx="14"/></clipPath>"#
        if year != nil { out += pawSymbol + tilePawSymbol(theme: theme) }
        for coat in coats {
            guard let coatFrames = frames[coat] else { continue }
            for (kind, list) in [("i", [coatFrames.idle]), ("g", coatFrames.groom)] {
                for (index, png) in list.enumerated() {
                    out += #"<image id="\#(safeId(coat))-\#(kind)\#(index)" width="\#(catSize)" height="\#(catSize)" "#
                        + #"href="data:image/png;base64,\#(png.base64EncodedString())"/>"#
                }
            }
        }
        out += "</defs>"
        out += #"<g clip-path="url(#card)">"#
        func band(_ band: SceneBand) -> String {
            #"<rect y="\#(number(band.top))" width="\#(number(cardWidth))" height="\#(number(band.height))" \#(fill(band.color))/>"#
        }
        for fill in scene.bands.prefix(CatRoomScene.artLayer) { out += band(fill) }
        if let art, let rects = scene.artRects(width: cardWidth) {
            for (rect, png) in [(rects.wall, art.wall), (rects.floor, art.floor)] {
                let x = rect.x == 0 ? "" : #" x="\#(number(rect.x))""#
                out += #"<image class="room"\#(x) y="\#(number(rect.y))" width="\#(number(rect.width))" "#
                    + #"height="\#(number(rect.height))" href="data:image/png;base64,\#(png.base64EncodedString())"/>"#
            }
        }
        for trim in scene.bands.dropFirst(CatRoomScene.artLayer) { out += band(trim) }
        if let calendar = scene.calendarProp { out += calendarElement(calendar) }
        let shadow = scene.shadow
        out += #"<ellipse cx="\#(number(cardWidth / 2))" cy="\#(number(shadow.top + shadow.height / 2))" "#
            + #"rx="\#(number(cardWidth / 2 - shadow.inset * scale))" ry="\#(number(shadow.height / 2))" \#(fill(shadow.color))/>"#
        for placed in scene.propRects(width: cardWidth) {
            guard let image = placed.prop.art?.image, let png = propArt[image] else { continue }
            let rect = placed.rect
            out += #"<image class="prop" x="\#(number(rect.x))" y="\#(number(rect.y))" width="\#(number(rect.width))" "#
                + #"height="\#(number(rect.height))" href="data:image/png;base64,\#(png.base64EncodedString())"/>"#
        }
        for track in simulate(drawn) {
            if let coatFrames = frames[track.coat] {
                out += catElement(track, frames: coatFrames, theme: theme, showsLevel: showsLevels)
            }
        }
        if let year {
            out += graph(year, showsNumbers: showsNumbers, theme: theme,
                         footer: footer(owner: owner, updated: updated, calendar: calendarSystem))
        }
        out += "</g></svg>"
        return out
    }

    /// Baloo 2 is embedded in the card; the rest is only a fallback if a viewer drops `@font-face`.
    private static let font = #"font-family="'\#(CardFont.family)',-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif""#
    private static let graphLeft = 24, graphTop = 346, cellSize = 12, cellPitch = 15
    private static let tileTop = 236, tileWidth = 264, tileRule = 312, footerY = 482

    /// A pixel paw for the busiest days, drawn once and reused; it takes the colour of each `<use>`.
    private static var pawSymbol: String {
        #"<symbol id="paw" viewBox="0 0 12 12">\#(SVGText.pixels(ContributionPaw.rows, mark: "X"))</symbol>"#
    }

    private static let tileIconSize = 18

    /// The brand paw every tile title wears, in the brightest grass colour.
    private static func tilePawSymbol(theme: RoomTheme) -> String {
        #"<symbol id="tile-paw" viewBox="0 0 16 16" shape-rendering="crispEdges"><g \#(fill(theme.levels[3]))>"#
            + #"\#(SVGText.pixels(BrandPaw.rows, mark: "o"))</g></symbol>"#
    }

    private static func graph(_ year: ContributionYear, showsNumbers: Bool, theme: RoomTheme, footer: String) -> String {
        let top = roomHeight, width = number(cardWidth)
        let ink = #"fill="\#(theme.ink.hex)" \#(font)"#
        var out = #"<rect y="\#(number(top))" width="\#(width)" height="\#(number(cardHeight - top))" \#(fill(theme.panel))/>"#
        out += #"<rect y="\#(number(top))" width="\#(width)" height="3" \#(fill(theme.panelEdge))/>"#
        out += #"<rect y="\#(number(top + 3))" width="\#(width)" height="1" \#(fill(theme.panelHighlight))/>"#
        // Three tiles (title, big value, caption) split by thin lines, with a rule under them.
        let stats = year.stats(showsNumbers: showsNumbers)
        if stats.isEmpty {
            out += #"<text x="\#(graphLeft)" y="\#(tileTop + 30)" font-size="20" font-weight="700" \#(ink)>"#
                + #"\#(SVGText.escape(year.headline(showsNumbers: showsNumbers)))</text>"#
        }
        for (index, stat) in stats.enumerated() {
            // Each tile is centred in its third of the card; the paw sits just left of the centred title.
            let left = graphLeft + index * tileWidth, centre = left + tileWidth / 2
            if index > 0 {
                out += #"<rect x="\#(left)" y="\#(tileTop - 12)" width="1" height="68" \#(fill(theme.ink)) opacity="0.25"/>"#
            }
            let titleCentre = centre + (tileIconSize + 6) / 2
            out += ##"<use href="#tile-paw" x="\##(titleCentre - Self.titleWidth(stat.title) / 2 - tileIconSize - 6)" "##
                + #"y="\#(tileTop - 14)" width="\#(tileIconSize)" height="\#(tileIconSize)"/>"#
            out += #"<text x="\#(titleCentre)" y="\#(tileTop)" font-size="11" letter-spacing="0.8" font-weight="600" opacity="0.7" "#
                + #"text-anchor="middle" \#(ink)>\#(SVGText.escape(stat.title))</text>"#
            let unit = stat.unit.map { #"<tspan dx="6" font-size="20" font-weight="700" opacity="0.7">\#(SVGText.escape($0))</tspan>"# } ?? ""
            out += #"<text x="\#(centre)" y="\#(tileTop + 36)" font-size="32" font-weight="800" text-anchor="middle" \#(ink)>"#
                + #"\#(SVGText.escape(stat.value))\#(unit)</text>"#
            out += #"<text x="\#(centre)" y="\#(tileTop + 56)" font-size="12" opacity="0.7" text-anchor="middle" \#(ink)>"#
                + #"\#(SVGText.escape(stat.caption))</text>"#
        }
        out += #"<rect x="\#(graphLeft)" y="\#(tileRule)" width="\#(Int(cardWidth) - 2 * graphLeft)" height="1" \#(fill(theme.ink)) opacity="0.25"/>"#
        for label in year.monthLabels {
            out += #"<text x="\#(graphLeft + label.column * cellPitch)" y="\#(graphTop - 8)" font-size="11" \#(ink)>\#(label.name)</text>"#
        }
        for (column, cells) in year.columns.enumerated() {
            for (row, cell) in cells.enumerated() {
                guard let level = cell.level else { continue }
                out += day(level: level, x: graphLeft + column * cellPitch, y: graphTop + row * cellPitch, theme: theme)
            }
        }
        out += #"<text x="\#(graphLeft)" y="\#(footerY)" font-size="11" opacity="0.85" \#(ink)>\#(SVGText.escape(footer))</text>"#
        let legendRight = Int(cardWidth) - graphLeft
        out += #"<text x="\#(legendRight)" y="\#(footerY)" font-size="11" text-anchor="end" \#(ink)>More</text>"#
        for level in 0..<4 {
            out += day(level: level, x: legendRight - 36 - (4 - level) * cellPitch, y: footerY - 10, theme: theme)
        }
        let lessRight = legendRight - 36 - 4 * cellPitch - 5
        out += #"<text x="\#(lessRight)" y="\#(footerY)" font-size="11" text-anchor="end" \#(ink)>Less</text>"#
        // The project's name and a paw, ending a gap before "Less".
        let brandRight = lessRight - 48, brandEnd = brandRight - 16
        out += ##"<use href="#paw" x="\##(brandRight - 11)" y="\##(footerY - 10)" width="11" height="11" fill="\##(theme.accent.hex)"/>"##
        out += #"<text x="\#(brandEnd)" y="\#(footerY)" font-size="11" font-weight="700" text-anchor="end" \#(ink)>"#
            + #"\#(TokenCatsBrand.name)</text>"#
        return out
    }

    /// Width of a tile title (Baloo 2 semibold 11px, letter-spacing 0.8): about 7.4px per uppercase letter, 3.6 per space.
    /// Only used to set the paw beside a centred title, so a pixel or two off does not show.
    private static func titleWidth(_ title: String) -> Int {
        Int(title.reduce(0.0) { $0 + ($1 == " " ? 3.6 : 7.4) }.rounded())
    }

    /// Every day is a rounded square so the graph reads as one; level 3 also carries a paw stamp.
    private static func day(level: Int, x: Int, y: Int, theme: RoomTheme) -> String {
        let clamped = min(max(level, 0), 3)
        let square = #"<rect x="\#(x)" y="\#(y)" width="\#(cellSize)" height="\#(cellSize)" rx="2" \#(fill(theme.levels[clamped]))/>"#
        guard clamped == 3 else { return square }
        return square + ##"<use href="#paw" x="\##(x)" y="\##(y)" width="\##(cellSize)" height="\##(cellSize)" fill="\##(theme.stamp.hex)"/>"##
    }

    /// `@owner · Updated Oct 10`; English month like the graph, independent of the Mac's language.
    private static func footer(owner: String?, updated: Date?, calendar: Calendar) -> String {
        var parts: [String] = []
        if let owner, !owner.isEmpty { parts.append("@\(owner)") }
        if let updated {
            let day = calendar.gregorian.dateComponents([.month, .day], from: updated)
            parts.append("Updated \(ContributionYear.monthNames[(day.month ?? 1) - 1]) \(day.day ?? 1)")
        }
        return parts.joined(separator: " · ")
    }

    static func safeId(_ coat: String) -> String {
        "c-" + String(coat.lowercased().map { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-") ? character : "-"
        })
    }

    private static func calendarElement(_ prop: CalendarProp) -> String {
        let pixel = Int(CalendarProp.pixel)
        var out = #"<svg x="\#(number(prop.left(inWidth: cardWidth)))" y="\#(number(prop.top))" "#
            + #"width="\#(CalendarProp.artWidth * pixel)" height="\#(CalendarProp.artHeight * pixel)">"#
        for rect in prop.rects {
            out += #"<rect x="\#(rect.x * pixel)" y="\#(rect.y * pixel)" width="\#(rect.width * pixel)" "#
                + #"height="\#(rect.height * pixel)" \#(fill(rect.color))/>"#
        }
        return out + "</svg>"
    }

    /// Runs the notch room with these residents and records every cat each tick.
    static func simulate(_ cats: [CatRoomSVGCat]) -> [CatTrack] {
        var room = CatRoom(household: CatHousehold(residents: cats.map { CatResidentRecord(id: $0.id, coat: $0.coat) }))
        var tracks = cats.map { CatTrack(id: $0.id, coat: $0.coat, level: $0.level, samples: []) }
        for step in 0..<Int((simulationSeconds / tick).rounded()) {
            let scene = room.step(dt: step == 0 ? 0 : tick, now: Double(step) * tick, width: simulationWidth)
            for cat in scene {
                guard let index = tracks.firstIndex(where: { $0.id == cat.id }) else { continue }
                tracks[index].samples.append(CatSample(x: cat.x, yOffset: cat.yOffset, pose: pose(of: cat)))
            }
        }
        return tracks.filter { !$0.samples.isEmpty }
    }

    private static func pose(of cat: CatSceneCat) -> String {
        switch cat.clip {
        case .idle: return "i0"
        case .groom: return "g\(cat.clipIndex)"
        case .walkRight: return "r\(cat.clipIndex)"
        case .walkLeft: return "l\(cat.clipIndex)"
        }
    }

    /// One cat sitting at its starting place, with a `<use>` per frame it shows: sitting, and grooming
    /// whenever the notch room grooms. Walking moments show sitting.
    private static func catElement(_ track: CatTrack, frames: CatCoatFrames, theme: RoomTheme,
                                   showsLevel: Bool) -> String {
        let id = safeId(track.coat)
        let timing = #"dur="\#(Int(simulationSeconds))s" repeatCount="indefinite""#
        let top = roomHeight - CatRoomScene.catFloorGap - Double(catSize)
        let x = track.samples[0].x * scale
        var out = #"<svg class="cat" x="\#(number(x, places: 3))" y="\#(number(top))" "#
            + #"width="\#(catSize)" height="\#(catSize)" overflow="visible">"#
        out += #"<g transform="translate(-\#(catSize / 2),0)">"#
        let available = Set(["i0"] + frames.groom.indices.map { "g\($0)" })
        let shown = track.samples.map { available.contains($0.pose) ? $0.pose : "i0" }
        for key in Set(shown).sorted(by: { ($0 == "i0" ? "" : $0) < ($1 == "i0" ? "" : $1) }) {
            let during = runs(shown) { $0 == key }
            let always = during.count == 1 && during[0] == (0, simulationSeconds)
            out += ##"<use href="#\##(id)-\##(key)" opacity="\##(shown[0] == key ? 1 : 0)">"##
                + (always ? "" : opacity(during: during, timing: timing)) + "</use>"
        }
        if showsLevel { out += levelTag(track.level, theme: theme) }
        return out + "</g></svg>"
    }

    /// Art pixels of plaque around the letters, sideways and up/down.
    private static let levelTagPadding = (x: 2, y: 1)

    /// `LV n` in the calendar's pixel letters on a small plaque, centred under the cat, inside its svg so it scales
    /// with the cat. Letters in `ink` on `panel`: the pair the card's stats use, so it reads on any floor.
    private static func levelTag(_ level: Int, theme: RoomTheme) -> String {
        let text = "LV \(level)"
        let pixel = Int(CalendarProp.pixel)
        let width = PixelGlyphs.width(of: text) * pixel
        let left = (catSize - width) / 2
        let padX = levelTagPadding.x * pixel, padY = levelTagPadding.y * pixel
        var out = #"<rect class="level" x="\#(left - padX)" y="\#(levelTagTop - padY)" "#
            + #"width="\#(width + 2 * padX)" height="\#(PixelGlyphs.glyphHeight * pixel + 2 * padY)" rx="\#(pixel)" "#
            + #"\#(fill(theme.panel))/>"#
        for rect in PixelGlyphs.rects(text, left: 0, top: 0, color: theme.ink) {
            out += #"<rect x="\#(left + rect.x * pixel)" y="\#(levelTagTop + rect.y * pixel)" "#
                + #"width="\#(rect.width * pixel)" height="\#(rect.height * pixel)" \#(fill(rect.color))/>"#
        }
        return out
    }

    /// Time ranges (seconds) of consecutive samples that match.
    private static func runs<Sample>(_ samples: [Sample], where matches: (Sample) -> Bool) -> [(Double, Double)] {
        var ranges: [(Double, Double)] = []
        var start: Int?
        for (index, sample) in samples.enumerated() {
            if matches(sample) {
                if start == nil { start = index }
            } else if let open = start {
                ranges.append((Double(open) * tick, Double(index) * tick))
                start = nil
            }
        }
        if let open = start { ranges.append((Double(open) * tick, simulationSeconds)) }
        return ranges
    }

    /// A discrete opacity animation that is 1 during the given ranges and 0 otherwise.
    private static func opacity(during: [(Double, Double)], timing: String) -> String {
        var times: [Double] = [0], values = [0]
        for (on, off) in during where off > on {
            if on <= times.last! { values[values.count - 1] = 1 } else { times.append(on); values.append(1) }
            if off < simulationSeconds { times.append(off); values.append(0) }
        }
        return #"<animate attributeName="opacity" values="\#(values.map(String.init).joined(separator: ";"))" "#
            + #"keyTimes="\#(times.map { fraction($0, simulationSeconds) }.joined(separator: ";"))" calcMode="discrete" \#(timing)/>"#
    }

    private static func fraction(_ seconds: Double, _ cycle: Double) -> String {
        number(min(1, max(0, seconds / cycle)), places: 5)
    }

    private static func fill(_ color: SceneColor) -> String {
        color.opacity < 1
            ? #"fill="\#(color.hex)" fill-opacity="\#(number(color.opacity))""#
            : #"fill="\#(color.hex)""#
    }

    /// Up to `places` decimals, trailing zeros dropped: 4 → "4", 170.5 → "170.5", 16.6667 → "16.67".
    private static func number(_ value: Double, places: Int = 2) -> String {
        var text = String(format: "%.\(places)f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
