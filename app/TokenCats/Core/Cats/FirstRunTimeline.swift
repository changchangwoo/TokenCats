/// The first-run scene in the notch, beat by beat: the notch unfolds onto the empty room, the first cat walks in
/// from the left, sits in the middle, grooms once and says hi. Then the notch folds up and the onboarding window opens.
enum FirstRunTimeline {
    struct Pose: Equatable, Sendable {
        let x: Double
        let clip: CatClip
        let index: Int
        var saysHi = false
    }

    /// Points along the room's floor (the room is `CatRoomScene.notchRoomWidth` wide).
    static let enterX = 40.0
    static let seatX = 308.0
    private static let walkSpeed = 110.0
    private static let walkFrames = 6
    private static let walkFPS = 8.0
    private static let groomFrames = 10
    /// The same floor as the room's own grooming: every pose shows for at least 1/8 second.
    private static let groomPoseDuration = 1.0 / 8.0

    /// The notch unfolds with the same spring as a normal open while the room fades in.
    static let unfoldDuration = 0.6
    /// Folding back up after the hi, before the onboarding window.
    static let foldDuration = 0.45

    static let walkStart = unfoldDuration + 0.1
    static let walkEnd = walkStart + (seatX - enterX) / walkSpeed
    static let groomStart = walkEnd + 0.4
    static let groomEnd = groomStart + Double(groomFrames) * groomPoseDuration
    static let hiStart = groomEnd + 0.15
    static let duration = hiStart + 1.2

    /// The cat at `time` seconds into the scene, or nil while the room is still empty.
    static func pose(at time: Double) -> Pose? {
        switch time {
        case ..<walkStart:
            return nil
        case ..<walkEnd:
            let walked = time - walkStart
            return Pose(x: enterX + walked * walkSpeed, clip: .walkRight, index: Int(walked * walkFPS) % walkFrames)
        case groomStart..<groomEnd:
            return Pose(x: seatX, clip: .groom, index: min(groomFrames - 1, Int((time - groomStart) / groomPoseDuration)))
        case hiStart...:
            return Pose(x: seatX, clip: .idle, index: 0, saysHi: true)
        default:
            return Pose(x: seatX, clip: .idle, index: 0)
        }
    }
}
