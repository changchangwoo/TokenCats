import Testing
@testable import TokenCatsCore

struct PixelGlyphsTests {
    @Test func everyGlyphIsThreeByFive() {
        #expect(PixelGlyphs.glyphs.values.allSatisfy { $0.count == 5 && $0.allSatisfy { $0.count == 3 } })
        for digit in "0123456789" { #expect(PixelGlyphs.glyphs[digit] != nil) }
        for letter in "LV" { #expect(PixelGlyphs.glyphs[letter] != nil) }
        // The calendar's month names still have every letter.
        for name in CalendarProp.monthNames { #expect(name.allSatisfy { PixelGlyphs.glyphs[$0] != nil }) }
        #expect(CalendarProp.glyphs == PixelGlyphs.glyphs)
    }

    @Test func widthCountsGlyphsGapsAndNarrowSpaces() {
        #expect(PixelGlyphs.width(of: "OCT") == 11)
        #expect(PixelGlyphs.width(of: "LV 99") == 17)
        #expect(PixelGlyphs.width(of: "LV 7") == 13)
        #expect(PixelGlyphs.width(of: "") == 0)
    }

    @Test func rectsRunLeftToRightOneRowAtATime() {
        let ink = SceneColor(red: 1, green: 2, blue: 3)
        let one = PixelGlyphs.rects("1", left: 10, top: 20, color: ink)
        // "1" is .X. / XX. / .X. / .X. / XXX → one run per row.
        #expect(one.map { "\($0.x),\($0.y),\($0.width)" } == ["11,20,1", "10,21,2", "11,22,1", "11,23,1", "10,24,3"])
        #expect(one.allSatisfy { $0.height == 1 && $0.color == ink })
        // A space advances by one pixel plus the gap; nothing is drawn for it.
        let spaced = PixelGlyphs.rects("L 1", left: 0, top: 0, color: ink)
        #expect(spaced.filter { $0.y == 4 }.map(\.x) == [0, 6])
        // Digits are distinct pictures.
        let pictures = Set("0123456789".map { PixelGlyphs.glyphs[$0]! })
        #expect(pictures.count == 10)
    }
}
