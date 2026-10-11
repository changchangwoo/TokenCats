import Testing
@testable import TokenCatsCore

/// The first-run scene: an empty room, the cat walks in, sits, grooms once, says hi.
struct FirstRunTimelineTests {
    @Test func theCatWaitsUntilTheNotchHasUnfolded() {
        #expect(FirstRunTimeline.walkStart > FirstRunTimeline.unfoldDuration)
    }

    @Test func startsWithAnEmptyRoom() {
        #expect(FirstRunTimeline.pose(at: 0) == nil)
        #expect(FirstRunTimeline.pose(at: FirstRunTimeline.walkStart - 0.01) == nil)
    }

    @Test func walksInFromTheLeftToTheMiddle() throws {
        let start = try #require(FirstRunTimeline.pose(at: FirstRunTimeline.walkStart))
        let later = try #require(FirstRunTimeline.pose(at: FirstRunTimeline.walkEnd - 0.01))
        #expect(start.clip == .walkRight)
        #expect(start.x == FirstRunTimeline.enterX)
        #expect(later.x > start.x && later.x <= FirstRunTimeline.seatX)
    }

    @Test func steppingCyclesThroughTheWalkPoses() {
        let indices = Set(stride(from: FirstRunTimeline.walkStart, to: FirstRunTimeline.walkEnd, by: 0.05)
            .compactMap { FirstRunTimeline.pose(at: $0)?.index })
        #expect(indices == Set(0..<6))
    }

    @Test func groomsThroughAllTenPosesThenSaysHi() throws {
        let indices = Set(stride(from: FirstRunTimeline.groomStart, to: FirstRunTimeline.groomEnd, by: 0.02)
            .compactMap { FirstRunTimeline.pose(at: $0) }.filter { $0.clip == .groom }.map(\.index))
        #expect(indices == Set(0..<10))
        let hi = try #require(FirstRunTimeline.pose(at: FirstRunTimeline.duration - 0.01))
        #expect(hi.clip == .idle && hi.saysHi && hi.x == FirstRunTimeline.seatX)
    }

    @Test func lastsAboutSixSeconds() {
        #expect((5...6.5).contains(FirstRunTimeline.duration))
    }
}
