import Testing
@testable import TokenCatsCore

struct CatRoomMotionTests {
    @Test func walkingUsesTheQuickerStride() {
        var cat = CatRoomMotion(x: 150, restOffset: 0, walksRightFirst: true)
        cat.planWalk(to: 300)
        cat.step(dt: 0.125, width: 400)

        #expect(cat.clip == .walkRight)
        #expect(cat.x > 150)
        #expect(cat.x - 150 == 7.5)
    }

    @Test func sharedRoomWalksHaveVariedRestIntervalsAndDirections() {
        var cat = CatRoomMotion(x: 150, restOffset: 0, walksRightFirst: true)
        var starts: [Double] = []
        var directions: [CatClip] = []
        var wasWalking = false
        for tick in 1...1_200 {
            cat.step(dt: 0.1, width: 600)
            let walking = cat.clip == .walkRight || cat.clip == .walkLeft
            if walking && !wasWalking {
                starts.append(Double(tick) * 0.1)
                directions.append(cat.clip)
            }
            wasWalking = walking
        }
        #expect(starts.count >= 6)
        let intervals = zip(starts, starts.dropFirst()).map { pair in
            Int(((pair.1 - pair.0) * 10).rounded())
        }
        #expect(Set(intervals).count >= 3)
        #expect(zip(directions, directions.dropFirst()).contains { pair in pair.0 == pair.1 })
        #expect(directions.contains(.walkRight) && directions.contains(.walkLeft))
    }

    @Test func residentStartsWithTheBottomLeftPoseAndWalksBothDirections() {
        var cat = CatRoomMotion()
        #expect(cat.x == 80)
        #expect(cat.clip == .idle)
        #expect(cat.clipIndex == 0)

        var sawRight = false
        var sawLeft = false
        for _ in 0..<2_400 {
            cat.step(dt: 0.1, width: 400)
            sawRight = sawRight || cat.clip == .walkRight
            sawLeft = sawLeft || cat.clip == .walkLeft
            if cat.clip == .walkRight || cat.clip == .walkLeft { #expect((0..<6).contains(cat.clipIndex)) }
        }
        #expect(sawRight)
        #expect(sawLeft)
    }

    @Test func residentStaysInsideTheRoomWhenItResizes() {
        var cat = CatRoomMotion()
        for _ in 0..<300 {
            cat.step(dt: 0.1, width: 180)
            #expect(cat.x >= 48)
            #expect(cat.x <= 132)
        }
    }

    @Test func groomingRepeatsSeveralTimesBeforeTheFirstWalk() {
        var cat = CatRoomMotion()
        var groomingBouts = 0
        var wasGrooming = false
        var returnedToDefault = false
        for _ in 0..<260 {
            cat.step(dt: 0.1, width: 400)
            let grooming = cat.clip == .groom
            if grooming && !wasGrooming { groomingBouts += 1 }
            if groomingBouts > 0 && cat.clip == .idle { returnedToDefault = true }
            wasGrooming = grooming
        }
        #expect(groomingBouts >= 3)
        #expect(returnedToDefault)
        #expect(cat.x == 80)
    }

    @Test func bothGroomingBoutsShowEveryPoseInOrderAtBalancedFrameRate() {
        var cat = CatRoomMotion()
        var bouts: [[Int]] = []
        var current: [Int] = []
        for _ in 0..<100 {
            cat.step(dt: 1.0 / 8.0, width: 400)
            if cat.clip == .groom {
                if current.last != cat.clipIndex { current.append(cat.clipIndex) }
            } else if !current.isEmpty {
                bouts.append(current)
                current = []
            }
        }
        #expect(bouts.count >= 2)
        #expect(bouts[0] == Array(0...9))
        #expect(bouts[1] == Array(0...9))
    }

    @Test func groomingMovingPosesAreHeldLongEnoughToReadAtTwelveFps() {
        var cat = CatRoomMotion()
        var frames: [Int] = []
        for _ in 0..<72 {
            cat.step(dt: 1.0 / 12.0, width: 400)
            if cat.clip == .groom { frames.append(cat.clipIndex) }
        }
        #expect(frames.count >= 15)
        #expect(frames.enumerated().compactMap { index, frame in
            index == 0 || frame != frames[index - 1] ? frame : nil
        } == Array(0...9))
    }

    @Test func batterySaverGroomingStillShowsEveryPose() {
        var cat = CatRoomMotion()
        var frames: [Int] = []
        for _ in 0..<28 {
            cat.step(dt: 0.25, width: 400)
            if cat.clip == .groom && frames.last != cat.clipIndex { frames.append(cat.clipIndex) }
        }
        #expect(frames == Array(0...9))
    }

    @Test func defaultPoseStillDominatesWhileGroomingRepeats() {
        var cat = CatRoomMotion()
        for _ in 0..<100 { cat.step(dt: 0.1, width: 400) }
        #expect(cat.x == 80)
        #expect(cat.clip == .idle)

        var defaultFrames = 0
        var groomingFrames = 0
        var walkingFrames = 0
        for _ in 0..<1_800 {
            cat.step(dt: 0.1, width: 400)
            if cat.clip == .idle { defaultFrames += 1 }
            if cat.clip == .groom { groomingFrames += 1 }
            if cat.isWalking { walkingFrames += 1 }
        }
        let ratio = Double(defaultFrames) / 1_800
        #expect(ratio >= 0.70)
        #expect(ratio <= 0.80)
        #expect(Double(groomingFrames) / 1_800 >= 0.17)
        #expect(Double(walkingFrames) / 1_800 <= 0.08)
    }

}
