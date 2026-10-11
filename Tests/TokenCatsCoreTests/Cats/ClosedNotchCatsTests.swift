import Testing
@testable import TokenCatsCore

struct ClosedNotchCatsTests {
    @Test func roomCatsSplitAcrossBothWings() {
        #expect(ClosedNotchCats.split(["a", "b", "c", "d"]) == .init(left: ["a", "b"], right: ["c", "d"]))
        #expect(ClosedNotchCats.split(["a", "b", "c"]) == .init(left: ["a"], right: ["b", "c"]))
        #expect(ClosedNotchCats.split(["a"]) == .init(left: [], right: ["a"]))
        #expect(ClosedNotchCats.split([String]()) == .init(left: [], right: []))
    }

    @Test func bothWingsTakeTheWiderSidesWidth() {
        #expect(ClosedNotchCats.wingSlots(count: 4) == 2)
        #expect(ClosedNotchCats.wingSlots(count: 3) == 2)
        #expect(ClosedNotchCats.wingSlots(count: 1) == 1)
        #expect(ClosedNotchCats.wingSlots(count: 0) == 0)
    }

    @Test func iconsKeepWholeArtPixels() {
        // Sizes step by 12pt with room above and below; a usual notch shows the cats at 24pt, like the store.
        #expect(ClosedNotchCats.iconSize(notchHeight: 38) == 24)
        #expect(ClosedNotchCats.iconSize(notchHeight: 32) == 24)
        #expect(ClosedNotchCats.iconSize(notchHeight: 31) == 12)
        #expect(ClosedNotchCats.iconSize(notchHeight: 48) == 36)
        #expect(ClosedNotchCats.iconSize(notchHeight: 0) == 0)
    }
}
