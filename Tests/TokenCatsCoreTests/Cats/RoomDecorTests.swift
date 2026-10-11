import Foundation
import Testing
@testable import TokenCatsCore

struct RoomDecorTests {
    @Test func aNewRoomHasTheCalendarOnTheLeftWall() {
        #expect(RoomDecor.starter.prop(in: .wallLeft) == .calendar)
        #expect(RoomDecor.starter.shows(.calendar))
        #expect(RoomProp.calendar.slot == .wallLeft)
    }

    @Test func takingThePropDownEmptiesItsSlot() {
        var decor = RoomDecor.starter
        decor.set(.calendar, shown: false)
        #expect(!decor.shows(.calendar))
        #expect(decor.prop(in: .wallLeft) == nil)
        decor.set(.calendar, shown: true)
        #expect(decor.shows(.calendar))
    }

    @Test func roundTripsThroughJSON() throws {
        var decor = RoomDecor.starter
        decor.set(.calendar, shown: false)
        let data = try JSONEncoder().encode(decor)
        #expect(try JSONDecoder().decode(RoomDecor.self, from: data) == decor)
    }

    @Test func floorPropsStandInTheirOwnSlot() {
        #expect(RoomProp.hideCrate.slot == .floorLeft)
        #expect(RoomProp.hideCrate.art == RoomPropArt(image: "prop-hide-crate", width: 53, height: 44))
        #expect(RoomProp.catTower.slot == .floorRight)
        #expect(RoomProp.catTower.art == RoomPropArt(image: "prop-cat-tower", width: 74, height: 104))
        #expect(RoomProp.yarnBall.slot == .floorMidRight)
        #expect(RoomProp.yarnBall.art == RoomPropArt(image: "prop-yarn-ball", width: 30, height: 26))
        #expect(RoomProp.calendar.art == nil)
        var decor = RoomDecor.starter
        decor.set(.hideCrate, shown: true)
        #expect(decor.shows(.hideCrate))
        #expect(decor.shows(.calendar))
        decor.set(.catTower, shown: true)
        #expect(decor.shownProps == [.calendar, .hideCrate, .catTower])
        decor.set(.hideCrate, shown: false)
        #expect(decor.prop(in: .floorLeft) == nil)
        #expect(RoomDecor.starter.shownProps == [.calendar])
    }

    @Test func floorSlotsSitAtFixedShareOfTheRoomWidth() {
        #expect(RoomSlot.floorLeft.floorXFraction == 0.12)
        #expect(RoomSlot.floorMidRight.floorXFraction == 0.68)
        #expect(RoomSlot.floorRight.floorXFraction == 0.88)
        #expect(RoomSlot.wallLeft.floorXFraction == nil)
    }

    @Test func onlyTheCalendarComesFree() {
        #expect(RoomProp.calendar.isStarter)
        #expect(!RoomProp.hideCrate.isStarter)
        #expect(!RoomProp.catTower.isStarter)
        #expect(!RoomProp.yarnBall.isStarter)
    }
}
