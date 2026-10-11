import Testing
@testable import TokenCatsCore

struct CatHeartInteractionTests {
    @Test func onlyClicksNearTheCatCreateHearts() {
        let cat = CatRoomMotion()
        var hearts = CatHeartInteraction()
        let farTap = hearts.tap(at: 0, point: RoomPoint(x: 300, y: 110), cat: cat, baseline: 172)
        let nearTap = hearts.tap(at: 0, point: RoomPoint(x: 80, y: 110), cat: cat, baseline: 172)
        #expect(!farTap)
        #expect(nearTap)
        #expect(hearts.side == .left || hearts.side == .right)
        #expect(hearts.progress(at: 0.3) != nil)
        #expect(hearts.progress(at: 1.0) == nil)
    }

    @Test func rapidClicksDoNotStackHeartBursts() {
        let cat = CatRoomMotion()
        let point = RoomPoint(x: 80, y: 110)
        var hearts = CatHeartInteraction()
        let first = hearts.tap(at: 10, point: point, cat: cat, baseline: 172)
        let second = hearts.tap(at: 10.4, point: point, cat: cat, baseline: 172)
        let third = hearts.tap(at: 11.49, point: point, cat: cat, baseline: 172)
        let fourth = hearts.tap(at: 11.5, point: point, cat: cat, baseline: 172)
        #expect(first)
        #expect(!second)
        #expect(!third)
        #expect(fourth)
    }
}
