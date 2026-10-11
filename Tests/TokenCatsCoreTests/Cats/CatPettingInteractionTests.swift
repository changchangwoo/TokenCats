import Testing
@testable import TokenCatsCore

struct CatPettingInteractionTests {
    @Test func aClickPlaysBothPettingFramesThenReturnsToTheCat() {
        let cat = CatRoomMotion()
        var petting = CatPettingInteraction()
        let began = petting.touch(at: 0, point: RoomPoint(x: 80, y: 110), cat: cat, baseline: 172)
        #expect(began)
        #expect(petting.frame(at: 0) == 0)
        #expect(petting.frame(at: 0.25) == 1)
        petting.end(at: 0.1)
        #expect(petting.frame(at: 0.35) != nil)
        #expect(petting.frame(at: 0.8) == nil)
    }

    @Test func rubbingRefreshesThePettingAnimation() {
        let cat = CatRoomMotion()
        var petting = CatPettingInteraction()
        let first = petting.touch(at: 0, point: RoomPoint(x: 80, y: 110), cat: cat, baseline: 172)
        let rubbed = petting.touch(at: 0.6, point: RoomPoint(x: 95, y: 115), cat: cat, baseline: 172)
        #expect(first)
        #expect(rubbed)
        petting.end(at: 0.7)
        #expect(petting.frame(at: 1.0) != nil)
        #expect(petting.frame(at: 1.4) == nil)
    }
}
