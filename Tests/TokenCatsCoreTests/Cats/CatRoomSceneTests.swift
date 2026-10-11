import Foundation
import Testing
@testable import TokenCatsCore

/// An October laid out like 2026: four days of September, then the 1st on cell 4, today on cell 13.
private func sampleMonth() -> ChuruMonthCalendar {
    ChuruMonthCalendar(month: 10, days: (0..<42).map { index in
        let state: CalendarDayState
        switch index {
        case ..<4, 35...: state = .outsideMonth
        case 4..<7: state = .beforeInstall
        case 7..<13: state = .used(level: index % 4)
        case 13: state = .used(level: 3)
        default: state = .future
        }
        return CalendarDay(dayKey: "d\(index)", state: state, isToday: index == 13)
    })
}

private let binding = SceneColor(red: 125, green: 99, blue: 89)

private func cells(_ rects: [ScenePixelRect]) -> [ScenePixelRect] {
    rects.filter { $0.width == 2 && $0.height == 2 }
}

struct CatRoomSceneTests {
    @Test func bandsAreWallFloorEdgeAndTrim() {
        let scene = CatRoomScene.notch(height: 190, calendar: nil)
        #expect(scene.bands == [
            SceneBand(top: 0, height: 190, color: SceneColor(red: 238, green: 226, blue: 212)),
            SceneBand(top: 122, height: 68, color: SceneColor(red: 202, green: 166, blue: 136)),
            SceneBand(top: 122, height: 5, color: SceneColor(red: 125, green: 99, blue: 89)),
            SceneBand(top: 127, height: 2, color: SceneColor(red: 213, green: 184, blue: 160)),
        ])
        #expect(scene.shadow == FloorShadow(inset: 40, top: 166, height: 9,
                                            color: SceneColor(red: 0, green: 0, blue: 0, opacity: 0.06)))
    }

    @Test func artSitsCenteredWithItsBottomOnTheFloor() throws {
        let scene = CatRoomScene(height: 190, calendarTop: 12, calendar: nil, theme: .cozy)
        #expect(scene.art == RoomTheme.cozy.art)
        let rects = try #require(scene.artRects(width: 616))
        #expect(rects.wall == SceneRect(x: -112, y: -10, width: 840, height: 132))
        #expect(rects.floor == SceneRect(x: -112, y: 122, width: 840, height: 68))
        #expect(CatRoomScene.artLayer == 2)
        #expect(scene.bands[CatRoomScene.artLayer].color == RoomTheme.cozy.floorEdge)
    }

    @Test func profileRoomShowsTheWholePicture() throws {
        let rects = try #require(CatRoomScene.profile(calendar: nil, theme: .cozy).artRects(width: 840))
        #expect(rects.wall == SceneRect(x: 0, y: 0, width: 840, height: 132))
        #expect(rects.floor == SceneRect(x: 0, y: 132, width: 840, height: 68))
    }

    @Test func noPictureNoRects() {
        #expect(CatRoomScene(height: 190, calendarTop: 12, calendar: nil, theme: plainTheme).artRects(width: 616) == nil)
    }

    @Test func aRoomWithoutTheCalendarDrawsNone() {
        #expect(CatRoomScene(height: 190, calendarTop: 12, calendar: nil, showsCalendar: false).calendarProp == nil)
        #expect(CatRoomScene.profile(calendar: nil, showsCalendar: false).calendarProp == nil)
        #expect(CatRoomScene.notch(height: 190, calendar: nil).calendarProp != nil)
    }

    @Test func calendarSitsTwelveFromTheTopInTheNotchAndEightInTheProfile() {
        #expect(CatRoomScene.notch(height: 190, calendar: nil).calendar.top == 12)
        let profile = CatRoomScene.profile(calendar: nil)
        #expect(profile.height == 200)
        #expect(profile.calendar.top == 8)
        #expect(profile.bands[1].top == 132)
    }

    @Test func calendarLeftIsSixPercentSnappedToTheArtPixel() {
        let calendar = CatRoomScene.notch(height: 190, calendar: nil).calendar
        #expect(calendar.left(inWidth: 616) == 36)
        #expect(calendar.left(inWidth: 600) == 36)
        #expect(calendar.left(inWidth: 650) == 40)
    }

    @Test func withoutDataTheCalendarIsBindingAndBlankPaper() {
        let rects = CatRoomScene.notch(height: 190, calendar: nil).calendar.rects
        #expect(rects == [
            ScenePixelRect(x: 0, y: 0, width: 24, height: 2, color: binding),
            ScenePixelRect(x: 0, y: 2, width: 24, height: 28, color: SceneColor(red: 244, green: 239, blue: 230)),
        ])
    }

    /// O (8 pixels) + C (7) + T (7), centred in the 24-pixel sheet.
    @Test func monthLabelIsDrawnInPixelLetters() {
        let label = CatRoomScene.profile(calendar: sampleMonth()).calendar.rects
            .filter { $0.y >= 4 && $0.y + $0.height <= 9 }
        #expect(label.allSatisfy { $0.color == binding })
        #expect(label.reduce(0) { $0 + $1.width * $1.height } == 22)
        #expect(label.allSatisfy { $0.x >= 6 && $0.x + $0.width <= 17 })
    }

    @Test func everyMonthNameHasGlyphs() {
        for name in CalendarProp.monthNames {
            #expect(name.count == 3)
            #expect(name.allSatisfy { CalendarProp.glyphs[$0] != nil })
        }
        #expect(CalendarProp.glyphs.values.allSatisfy { $0.count == 5 && $0.allSatisfy { $0.count == 3 } })
    }

    @Test func eachDayOfTheMonthGetsASquareInItsColour() {
        let squares = cells(CatRoomScene.profile(calendar: sampleMonth()).calendar.rects)
        #expect(squares.count == 31)
        // The 1st: row 0, column 4, before install.
        #expect(squares[0] == ScenePixelRect(x: 14, y: 11, width: 2, height: 2, color: CalendarProp.empty))
        // Cell 8: row 1, column 1, level 0.
        #expect(squares[4] == ScenePixelRect(x: 5, y: 14, width: 2, height: 2, color: CalendarProp.levels[0]))
        // Cell 13 (today): row 1, column 6, level 3.
        #expect(squares[9] == ScenePixelRect(x: 20, y: 14, width: 2, height: 2, color: CalendarProp.levels[3]))
        #expect(squares.filter { $0.color == CalendarProp.empty }.count == 3 + 21)
    }

    @Test func todayIsOutlinedInTheGap() {
        let rects = CatRoomScene.profile(calendar: sampleMonth()).calendar.rects
        #expect(Array(rects.suffix(4)) == [
            ScenePixelRect(x: 19, y: 13, width: 4, height: 1, color: binding),
            ScenePixelRect(x: 19, y: 16, width: 4, height: 1, color: binding),
            ScenePixelRect(x: 19, y: 14, width: 1, height: 2, color: binding),
            ScenePixelRect(x: 22, y: 14, width: 1, height: 2, color: binding),
        ])
    }

    @Test func sixRowsStayInsideThePaper() {
        let full = ChuruMonthCalendar(month: 8, days: (0..<42).map {
            CalendarDay(dayKey: "d\($0)", state: .used(level: 1), isToday: $0 == 41)
        })
        let rects = CatRoomScene.profile(calendar: full).calendar.rects.dropFirst(2)
        #expect(rects.allSatisfy { $0.x >= 1 && $0.x + $0.width <= CalendarProp.artWidth - 1 })
        #expect(rects.allSatisfy { $0.y >= 4 && $0.y + $0.height <= CalendarProp.artHeight - 1 })
        #expect(cells(Array(rects)).allSatisfy { $0.y + $0.height <= CalendarProp.artHeight - 2 })
    }

    @Test func hexIsUppercaseSixDigits() {
        #expect(SceneColor(red: 47, green: 125, blue: 59).hex == "#2F7D3B")
    }

    @Test func floorPropsStandOnTheCatsFloorAtTheirSlotShare() {
        let notch = CatRoomScene(height: 190, calendarTop: 12, calendar: nil, props: [.calendar, .hideCrate])
        #expect(notch.props == [.hideCrate])
        // 616 × 12% = 73.92, so the 53pt crate starts at 47; its bottom is on the cats' floor.
        #expect(notch.propRects(width: 616) == [PlacedProp(prop: .hideCrate,
                                                            rect: SceneRect(x: 47, y: 128, width: 53, height: 44))])
        let card = CatRoomScene.profile(calendar: nil, props: [.hideCrate])
        // 840 × 12% = 100.8 → 74 after taking half the width; drawn at its own size, not scaled.
        #expect(card.propRects(width: 840) == [PlacedProp(prop: .hideCrate,
                                                          rect: SceneRect(x: 74, y: 138, width: 53, height: 44))])
        #expect(CatRoomScene.notch(height: 190, calendar: nil).props.isEmpty)
        // 616 × 88% = 542.08 → the 74pt tower starts at 505 and stands 104pt tall from the cats' floor.
        let tower = CatRoomScene(height: 190, calendarTop: 12, calendar: nil, props: [.catTower])
        #expect(tower.propRects(width: 616) == [PlacedProp(prop: .catTower,
                                                            rect: SceneRect(x: 505, y: 68, width: 74, height: 104))])
    }
}
