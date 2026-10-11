import Foundation
import Testing
@testable import TokenCatsCore

private func fakeFrames(bytes: Int = 16, groom: Int = 10, walk: Int = 6) -> CatCoatFrames {
    let frame = Data(repeating: 0xAB, count: bytes)
    return CatCoatFrames(idle: frame, groom: Array(repeating: frame, count: groom),
                         walkRight: Array(repeating: frame, count: walk), walkLeft: Array(repeating: frame, count: walk))
}

private func occurrences(_ needle: String, in text: String) -> Int {
    text.components(separatedBy: needle).count - 1
}

private func october() -> ChuruMonthCalendar {
    ChuruMonthCalendar(month: 10, days: (0..<42).map { index in
        let state: CalendarDayState
        switch index {
        case ..<4, 35...: state = .outsideMonth
        case 4..<7: state = .beforeInstall
        case 7...13: state = .used(level: index % 4)
        default: state = .future
        }
        return CalendarDay(dayKey: "2026-10-\(index)", state: state, isToday: index == 13)
    })
}

struct CatRoomSVGTests {
    private let cats = [CatRoomSVGCat(id: "black-1", coat: "black"), CatRoomSVGCat(id: "white-1", coat: "white")]
    private let frames = ["black": fakeFrames(), "white": fakeFrames()]

    private func year(_ daily: [String: Int] = ["2026-10-10": 12_000_000, "2026-10-09": 4_000_000]) -> ContributionYear {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.firstWeekday = 1
        return ContributionYear.make(dailyTokens: daily,
                                     today: calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 12))!,
                                     thresholds: [3_000_000, 10_000_000], calendar: calendar)
    }

    @Test func cardHasAFixedRatioSoGitHubKeepsItWhole() {
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year())
        #expect(svg.hasPrefix(#"<svg xmlns="http://www.w3.org/2000/svg" width="840" height="504" viewBox="0 0 840 504">"#))
        #expect(svg.contains(#"<clipPath id="card"><rect width="840" height="504" rx="14"/></clipPath>"#))
        #expect(occurrences("clip-path=", in: svg) == 1)
        let roomOnly = CatRoomSVG.render(calendar: nil, cats: [], frames: [:])
        #expect(roomOnly.hasPrefix(#"<svg xmlns="http://www.w3.org/2000/svg" width="840" height="200" viewBox="0 0 840 200">"#))
    }

    /// No gap and no second set of corners: the graph area is the floor carried on below the room.
    @Test func graphContinuesTheFloorBelowTheRoom() {
        let theme = RoomTheme.cozy
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), showsNumbers: true)
        #expect(svg.contains(#"<rect y="200" width="840" height="304" fill="\#(theme.panel.hex)"/>"#))
        #expect(svg.contains(#"<rect y="200" width="840" height="3" fill="\#(theme.panelEdge.hex)"/>"#))
        #expect(svg.contains(#"<rect y="203" width="840" height="1" fill="\#(theme.panelHighlight.hex)"/>"#))
        // Three tiles, each centred in its third of the card: paw and small title, big value, caption.
        // Dividers sit on the boundaries between the thirds, and a rule runs under them.
        #expect(svg.contains(#"<symbol id="tile-paw" viewBox="0 0 16 16" shape-rendering="crispEdges">"#))
        for (centre, title) in [(156, "TOTAL TOKENS"), (420, "DAILY AVERAGE"), (684, "CURRENT STREAK")] {
            #expect(svg.contains(#"<text x="\#(centre + 12)" y="236" font-size="11" letter-spacing="0.8""#))
            #expect(svg.contains(#"text-anchor="middle""#))
            #expect(svg.contains(">\(title)</text>"))
            #expect(svg.contains(#"<text x="\#(centre)" y="272" font-size="32" font-weight="800" text-anchor="middle""#))
            #expect(svg.contains(#"<text x="\#(centre)" y="292" font-size="12" opacity="0.7" text-anchor="middle""#))
        }
        for divider in [288, 552] {
            #expect(svg.contains(#"<rect x="\#(divider)" y="224" width="1" height="68""#))
        }
        #expect(svg.contains(">16.0M</text>") && svg.contains(">8.0M</text>"))
        #expect(svg.contains(#">2<tspan dx="6" font-size="20" font-weight="700" opacity="0.7">days</tspan></text>"#))
        #expect(svg.contains(">Last 365 days</text>") && svg.contains(">Tokens / active day</text>"))
        #expect(svg.contains(">Personal best · 2 days</text>"))
        #expect(occurrences(#"width="1" height="68""#, in: svg) == 2)
        #expect(svg.contains(#"<rect x="24" y="312" width="792" height="1""#))
        #expect(svg.contains(#"fill="\#(theme.ink.hex)""#))
        // Baloo 2 travels inside the card, so every viewer gets the same rounded letters.
        #expect(svg.contains(#"@font-face{font-family:"Baloo 2";font-weight:400 800;src:url(data:font/woff2;base64,"#))
        #expect(svg.contains(#"font-family="'Baloo 2',"#))
        // The room alone has no text, so it carries no font.
        #expect(!CatRoomSVG.render(calendar: nil, cats: [], frames: [:]).contains("@font-face"))
    }

    /// Every day stays a square so the graph reads; the busiest days carry a dark paw stamp inside.
    @Test func busiestDaysCarryAPawStamp() {
        let theme = RoomTheme.cozy
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), showsNumbers: true)
        #expect(svg.contains(#"<symbol id="paw" viewBox="0 0 12 12">"#))
        #expect(occurrences(#"width="12" height="12" rx="2""#, in: svg) == 53 * 7 + 4)
        // One level-3 day (12M on Oct 10), the legend's swatch, and the TokenCats mark.
        #expect(occurrences(##"<use href="#paw""##, in: svg) == 3)
        // Oct 10 is the last column and row: x 24 + 52 × 15, y 346 + 6 × 15.
        #expect(svg.contains(#"<rect x="804" y="436" width="12" height="12" rx="2" fill="\#(theme.levels[3].hex)"/>"#
                             + ##"<use href="#paw" x="804" y="436" width="12" height="12" fill="\##(theme.stamp.hex)"/>"##))
    }

    @Test func footerNamesTheOwnerAndTheDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 9))!
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), owner: "neko",
                                    updated: day, calendarSystem: calendar)
        #expect(svg.contains(">@neko · Updated Oct 10</text>"))
        let anonymous = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), updated: day,
                                          calendarSystem: calendar)
        #expect(anonymous.contains(">Updated Oct 10</text>"))
    }

    /// The room is the notch room scaled to the card: positions move by 840 / 616.
    @Test func roomPlacementScalesFromTheNotch() {
        let svg = CatRoomSVG.render(calendar: october(), cats: [], frames: [:])
        #expect(svg.contains(#"<svg x="50" y="8" width="48" height="60">"#))
    }

    @Test func themesColourTheWholeCard() {
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), theme: plainTheme)
        #expect(svg.contains(#"fill="\#(plainTheme.panel.hex)""#))
        #expect(svg.contains(#"fill="\#(plainTheme.wall.hex)""#))
        #expect(!svg.contains(#"fill="\#(RoomTheme.cozy.panel.hex)""#))
    }

    @Test func numbersStayOutWhenOff() {
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), showsNumbers: false)
        #expect(svg.contains(">Coding agent activity in the last year</text>"))
        #expect(!svg.contains("TOTAL TOKENS") && !svg.contains("Personal best"))
        #expect(!svg.contains("16.0M") && !svg.contains("8.0M"))
    }

    @Test func withoutAYearTheSvgIsUnchanged() {
        #expect(CatRoomSVG.render(calendar: october(), cats: cats, frames: frames)
                == CatRoomSVG.render(calendar: october(), cats: cats, frames: frames, year: nil, showsNumbers: true))
        #expect(!CatRoomSVG.render(calendar: october(), cats: cats, frames: frames).contains("<text"))
    }

    @Test func sameInputGivesSameBytes() {
        let first = CatRoomSVG.render(calendar: october(), cats: cats, frames: frames)
        let second = CatRoomSVG.render(calendar: october(), cats: cats, frames: frames)
        #expect(first == second)
    }

    @Test func carriesNoTextDatesOrTokenNumbers() {
        let svg = CatRoomSVG.render(calendar: october(), cats: cats, frames: frames)
        #expect(!svg.contains("<text"))
        #expect(!svg.contains("2026-"))
        #expect(!svg.contains("12345678"))
    }

    @Test func drawsOneSquarePerShownDayInItsLevelColour() {
        let svg = CatRoomSVG.render(calendar: october(), cats: [], frames: [:])
        let used = october().days.compactMap { day -> Int? in
            if case let .used(level) = day.state { return level }
            return nil
        }
        for level in 0..<4 {
            let fill = #"fill="\#(CalendarProp.levels[level].hex)""#
            #expect(occurrences(fill, in: svg) == used.filter { $0 == level }.count)
        }
        #expect(occurrences(#"fill="\#(CalendarProp.empty.hex)""#, in: svg) == 3 + 21)
    }

    @Test func eachCoatIsEmbeddedOnce() {
        let twins = [CatRoomSVGCat(id: "black-1", coat: "black"), CatRoomSVGCat(id: "black-2", coat: "black")]
        let svg = CatRoomSVG.render(calendar: nil, cats: twins, frames: ["black": fakeFrames()])
        #expect(occurrences("data:image/png;base64,", in: svg) == 11)
        #expect(occurrences(#"<svg class="cat""#, in: svg) == 2)
    }

    /// The profile replays the notch room's own logic, including brief overlaps on the same floor.
    @Test func catsBrieflyOverlapWithoutChangingFloorHeight() {
        let four = (1...4).map { CatRoomSVGCat(id: "cat-\($0)", coat: "black") }
        let tracks = CatRoomSVG.simulate(four)
        #expect(tracks.count == 4)
        var overlapped = false
        for sample in tracks[0].samples.indices {
            for a in tracks.indices {
                for b in tracks.indices where b > a {
                    let first = tracks[a].samples[sample], second = tracks[b].samples[sample]
                    if abs(first.x - second.x) < 88 {
                        overlapped = true
                        #expect(first.yOffset == 0 && second.yOffset == 0)
                    }
                }
            }
        }
        #expect(overlapped)
        #expect(tracks.contains { $0.samples.contains { $0.pose.hasPrefix("r") || $0.pose.hasPrefix("l") } })
        #expect(tracks.contains { $0.samples.contains { $0.pose.hasPrefix("g") } })
    }

    /// The profile is the notch room itself: same width, same positions and poses tick for tick.
    @Test func replaysTheNotchRoomExactly() {
        #expect(CatRoomSVG.simulationWidth == CatRoomScene.notchRoomWidth)
        #expect(CatRoomScene.notchRoomWidth == 616)
        let four = ["black", "white", "tabby", "cheese"].map { CatRoomSVGCat(id: "\($0)-1", coat: $0) }
        let tracks = CatRoomSVG.simulate(four)
        var room = CatRoom(household: CatHousehold(residents: four.map { CatResidentRecord(id: $0.id, coat: $0.coat) }))
        for step in 0..<600 {
            let scene = room.step(dt: step == 0 ? 0 : 1.0 / 12, now: Double(step) / 12, width: 616)
            #expect(scene.map(\.x) == tracks.map { $0.samples[step].x })
        }
    }

    @Test func housematesDoNotMoveInStep() {
        let tracks = CatRoomSVG.simulate(cats)
        #expect(tracks[0].samples.map(\.pose) != tracks[1].samples.map(\.pose))
    }

    /// The profile is still: cats sit where the notch room first places them and only groom.
    @Test func catsSitWhereTheNotchPlacesThemAndOnlyGroom() {
        let four = ["black", "white", "tabby", "cheese"].map { CatRoomSVGCat(id: "\($0)-1", coat: $0) }
        let svg = CatRoomSVG.render(calendar: nil, cats: four,
                                    frames: Dictionary(uniqueKeysWithValues: four.map { ($0.coat, fakeFrames()) }))
        #expect(!svg.contains(#"attributeName="x""#))
        #expect(!svg.contains(#"attributeName="y""#))
        #expect(!svg.contains("cat-back"))
        #expect(!svg.contains(##"href="#c-black-r"##) && !svg.contains(##"href="#c-black-l"##))
        #expect(!svg.contains(#"id="c-black-r0""#))
        let starts = CatRoomSVG.simulate(four).map { $0.samples[0].x * CatRoomSVG.cardWidth / CatRoomScene.notchRoomWidth }
        for start in starts {
            let x = String(format: "%.3f", start).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
            #expect(svg.contains(#"<svg class="cat" x="\#(x)" y="86""#))
        }
        #expect(svg.contains(##"href="#c-black-g9""##))
        #expect(svg.contains(#"dur="\#(Int(CatRoomSVG.simulationSeconds))s""#))
        #expect(!svg.contains(#"attributeName="visibility""#))
    }

    @Test func missingClipsFallBackToSitting() {
        let svg = CatRoomSVG.render(calendar: nil, cats: [cats[0]], frames: ["black": fakeFrames(groom: 0, walk: 0)])
        #expect(!svg.contains(##"href="#c-black-g"##))
        #expect(!svg.contains(##"href="#c-black-r"##))
        #expect(occurrences(##"<use href="#c-black-i0""##, in: svg) == 1)
    }

    /// Without animation support the front copy shows the cat sitting where it starts.
    @Test func idlePoseShowsWhenNothingAnimates() {
        let svg = CatRoomSVG.render(calendar: nil, cats: [cats[0]], frames: frames)
        #expect(svg.contains(##"<use href="#c-black-i0" opacity="1">"##))
        #expect(svg.contains(##"<use href="#c-black-g0" opacity="0">"##))
    }

    @Test func skipsCatsWithoutFramesAndStillDrawsTheRoom() {
        let mixed = [CatRoomSVGCat(id: "ghost-1", coat: "ghost"), CatRoomSVGCat(id: "empty-1", coat: "empty")]
        let svg = CatRoomSVG.render(calendar: october(), cats: mixed,
                                    frames: ["empty": CatCoatFrames(idle: Data(), groom: [], walkRight: [], walkLeft: [])])
        #expect(!svg.contains(#"<svg class="cat"#))
        #expect(!svg.contains("data:image/png"))
        #expect(svg.contains(#"fill="\#(CalendarProp.paper.hex)""#))
        #expect(svg.hasSuffix("</svg>"))
    }

    @Test func takenDownCalendarLeavesTheProfileWall() {
        let paper = #"fill="\#(CalendarProp.paper.hex)""#
        #expect(CatRoomSVG.render(calendar: october(), cats: [], frames: [:]).contains(paper))
        #expect(!CatRoomSVG.render(calendar: october(), cats: [], frames: [:], showsCalendar: false).contains(paper))
    }

    @Test func cardCarriesTheProjectNameBesideTheLegend() {
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), owner: "neko")
        #expect(TokenCatsBrand.name == "TokenCats")
        // The name alone, no tagline after it.
        #expect(svg.contains(">TokenCats</text>"))
        // A room-only card has no footer line, so no name either.
        #expect(!CatRoomSVG.render(calendar: nil, cats: [], frames: [:]).contains("TokenCats"))
    }

    /// The footer is who and when: "@owner · Updated Oct 10", nothing more.
    @Test func footerNamesOnlyTheOwnerAndTheDay() {
        let day = Date(timeIntervalSince1970: 1_791_590_400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), owner: "neko", updated: day,
                                    calendarSystem: calendar)
        #expect(svg.contains(">@neko · Updated Oct 10</text>"))
        #expect(!svg.contains("last 7 days"))
    }

    @Test func showsAtMostTheRoomsCats() {
        let many = (1...8).map { CatRoomSVGCat(id: "black-\($0)", coat: "black") }
        let svg = CatRoomSVG.render(calendar: nil, cats: many, frames: ["black": fakeFrames()])
        #expect(occurrences(#"<svg class="cat""#, in: svg) == CatRoomSVG.maxCats)
        #expect(CatRoomSVG.maxCats == CatHousehold.roomCapacity)
    }

    @Test func coatNamesBecomeSafeIds() {
        #expect(CatRoomSVG.safeId("Tabby cat\"<x>") == "c-tabby-cat--x-")
        let svg = CatRoomSVG.render(calendar: nil, cats: [CatRoomSVGCat(id: "t-1", coat: "Tabby cat")],
                                    frames: ["Tabby cat": fakeFrames()])
        #expect(svg.contains(#"id="c-tabby-cat-i0""#))
        #expect(svg.contains(##"href="#c-tabby-cat-i0""##))
    }

    /// Real 96px frames re-encoded by ImageIO average 8.0–12.2KB per coat (≈9.8KB overall).
    @Test func fiveCoatsStayUnderTwoMegabytes() {
        let coats = (1...5).map { "coat\($0)" }
        let svg = CatRoomSVG.render(
            calendar: october(),
            cats: coats.map { CatRoomSVGCat(id: "\($0)-1", coat: $0) },
            frames: Dictionary(uniqueKeysWithValues: coats.map { ($0, fakeFrames(bytes: 9_800)) }))
        #expect(svg.utf8.count <= CatRoomSVG.maxBytes)
        #expect(CatRoomSVG.maxBytes == 2_000_000)
    }

    private func cozyArt() throws -> RoomArtPNGs {
        let dir = resourcesURL.appendingPathComponent("RoomArt")
        return RoomArtPNGs(wall: try Data(contentsOf: dir.appendingPathComponent("room-cozy-wall.png")),
                           floor: try Data(contentsOf: dir.appendingPathComponent("room-cozy-floor.png")))
    }

    @Test func embedsWallAndFloorBetweenFillAndEdge() throws {
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], theme: .cozy, art: try cozyArt())
        let fill = try #require(svg.range(of: #"fill="\#(RoomTheme.cozy.floor.hex)""#))
        let wall = try #require(svg.range(of: #"<image class="room" y="0" width="840" height="132" href="data:image/png;base64,"#))
        let floor = try #require(svg.range(of: #"<image class="room" y="132" width="840" height="68" href="data:image/png;base64,"#))
        let edge = try #require(svg.range(of: #"fill="\#(RoomTheme.cozy.floorEdge.hex)""#))
        #expect(fill.lowerBound < wall.lowerBound)
        #expect(wall.lowerBound < floor.lowerBound)
        #expect(floor.lowerBound < edge.lowerBound)
        #expect(!CatRoomSVG.render(calendar: nil, cats: [], frames: [:], theme: .cozy).contains(#"class="room""#))
        #expect(!CatRoomSVG.render(calendar: nil, cats: [], frames: [:], theme: plainTheme, art: try cozyArt())
            .contains(#"class="room""#))
    }

    @Test func placedPropsStandBetweenTheShadowAndTheCats() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let svg = CatRoomSVG.render(calendar: nil, cats: cats, frames: frames, props: [.hideCrate],
                                    propArt: ["prop-hide-crate": png])
        let shadow = try #require(svg.range(of: "<ellipse"))
        let prop = try #require(svg.range(of: #"<image class="prop" x="74" y="138" width="53" height="44" href="data:image/png;base64,\#(png.base64EncodedString())"/>"#))
        let cat = try #require(svg.range(of: #"<svg class="cat""#))
        #expect(shadow.lowerBound < prop.lowerBound)
        #expect(prop.lowerBound < cat.lowerBound)
        // Without its picture a prop is left out, and nothing placed leaves the card as it was.
        #expect(!CatRoomSVG.render(calendar: nil, cats: cats, frames: frames, props: [.hideCrate]).contains(#"class="prop""#))
        #expect(CatRoomSVG.render(calendar: nil, cats: cats, frames: frames, props: [], propArt: ["prop-hide-crate": png])
                == CatRoomSVG.render(calendar: nil, cats: cats, frames: frames))
    }

    @Test func budgetHoldsWithPicturesAndFiveCats() throws {
        let coats = (1...5).map { "coat\($0)" }
        let svg = try CatRoomSVG.checkedRender(
            calendar: october(),
            cats: coats.map { CatRoomSVGCat(id: "\($0)-1", coat: $0) },
            frames: Dictionary(uniqueKeysWithValues: coats.map { ($0, fakeFrames(bytes: 9_800)) }),
            year: year(), theme: .cozy, art: try cozyArt())
        #expect(svg.utf8.count <= CatRoomSVG.maxBytes)
    }

    @Test func checkedRenderRefusesAnSvgOverTheBudget() {
        let coats = (1...5).map { "coat\($0)" }
        #expect(throws: CatRoomSVG.TooLarge.self) {
            try CatRoomSVG.checkedRender(
                calendar: october(),
                cats: coats.map { CatRoomSVGCat(id: "\($0)-1", coat: $0) },
                frames: Dictionary(uniqueKeysWithValues: coats.map { ($0, fakeFrames(bytes: 40_000)) }))
        }
    }

    @Test func footerDateIsGregorianWhateverTheMacsCalendar() {
        let day = Date(timeIntervalSince1970: 1_791_590_400)
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let svg = CatRoomSVG.render(calendar: nil, cats: [], frames: [:], year: year(), owner: "neko", updated: day,
                                    calendarSystem: hebrew)
        #expect(svg.contains(">@neko · Updated Oct 10</text>"))
    }
}
