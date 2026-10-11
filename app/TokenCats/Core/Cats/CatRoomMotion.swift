import Foundation

enum CatClip: String, Sendable { case idle, walkRight, walkLeft, groom }

/// One resident cat: where it is and which pose of which clip it shows. Poses are named by clip and position in
/// the clip; `cat-assets.json` maps them to sheet frames, so the sheet layout never leaks in here.
struct CatRoomMotion: Sendable {
    private static let restDuration = 28.0
    private static let walkDuration = 1.2
    private static let walkSpeed = 60.0
    private static let sharedRestDurations = [7.0, 9.5, 11.0, 8.0, 10.0]
    private static let groomStarts = [4.0, 10.5, 17.0, 23.5]
    /// Each of the ten poses lasts at least 1/8 second. At 4 fps the bout stretches so
    /// battery saver still shows every pose instead of jumping over half of them.
    private static let minimumGroomPoseDuration = 1.0 / 8.0

    private(set) var x = 80.0
    private(set) var clip = CatClip.idle
    private(set) var clipIndex = 0
    private var restDuration = 28.0
    private var destination: Double?
    private var sharedRoom = false
    private var rhythmSeed = 0
    private var walksCompleted = 0
    private var groomPoseDuration = Self.minimumGroomPoseDuration

    private enum Phase { case resting, walkingRight, walkingLeft }
    private var phase: Phase = .resting
    private var nextWalksRight = true
    private var phaseTime = 0.0

    init() {}

    /// A resident placed in a shared room: `restOffset` starts it part-way through its rest so housemates
    /// do not groom and walk in lockstep.
    init(x: Double, restOffset: Double, walksRightFirst: Bool, rhythmSeed: Int = 0) {
        self.x = x
        restDuration = 10.0
        sharedRoom = true
        self.rhythmSeed = rhythmSeed
        phaseTime = min(max(0, restOffset), restDuration - 0.1)
        nextWalksRight = walksRightFirst
    }

    /// Moves the cat without changing what it is doing (used once the room's width is known).
    mutating func place(x: Double) { self.x = x }

    var isWalking: Bool { phase != .resting }

    mutating func planWalk(to target: Double) {
        destination = target
        phase = target >= x ? .walkingRight : .walkingLeft
        phaseTime = 0
    }

    /// Another cat is already passing; retry soon without changing direction.
    mutating func waitForClearLane() {
        phase = .resting
        phaseTime = max(0, restDuration - 1)
        show(.idle)
        destination = nil
    }

    func plannedWalkEndpoint(width: Double) -> Double? {
        if let destination { return destination }
        let left = 48.0, right = max(left, width - 48)
        let distance = Self.walkSpeed * Self.walkDuration
        switch phase {
        case .walkingRight: return min(right, x + distance)
        case .walkingLeft: return max(left, x - distance)
        case .resting: return nil
        }
    }

    /// A neighbor blocked the next step. Rest here, then try walking away next time.
    mutating func yieldToNeighbor() {
        switch phase {
        case .walkingRight: nextWalksRight = false
        case .walkingLeft: nextWalksRight = true
        case .resting: return
        }
        phase = .resting
        phaseTime = 0
        show(.idle)
        destination = nil
    }

    func isNear(_ point: RoomPoint, baseline: Double) -> Bool {
        abs(point.x - x) <= 52 && point.y >= baseline - 94 && point.y <= baseline - 2
    }

    private mutating func finishWalk(wasRight: Bool) {
        phase = .resting
        phaseTime = 0
        show(.idle)
        destination = nil
        walksCompleted += 1
        if sharedRoom {
            restDuration = Self.sharedRestDurations[(walksCompleted + rhythmSeed * 2) % Self.sharedRestDurations.count]
            let keepsDirection = (walksCompleted + rhythmSeed) % 3 == 0
            nextWalksRight = keepsDirection ? wasRight : !wasRight
        } else {
            nextWalksRight = !wasRight
        }
    }

    private mutating func show(_ clip: CatClip, _ index: Int = 0) {
        self.clip = clip
        clipIndex = index
    }

    mutating func step(dt: Double, width: Double) {
        guard dt > 0, dt.isFinite else { return }
        let left = 48.0
        let right = max(left, width - 48)
        x = min(max(x, left), right)
        phaseTime += dt

        switch phase {
        case .resting:
            // Grooming is part of resting, so it also happens before the first walk.
            let continuingGroom = clip == .groom
            show(.idle)
            for start in Self.groomStarts {
                let elapsed = phaseTime - start
                let poseDuration = continuingGroom ? groomPoseDuration : max(Self.minimumGroomPoseDuration, dt)
                if elapsed >= 0 && elapsed < 10 * poseDuration {
                    if !continuingGroom { groomPoseDuration = poseDuration }
                    let frame = Int(elapsed / groomPoseDuration + 1e-8)
                    show(.groom, min(9, frame))
                    break
                }
            }
            if phaseTime >= restDuration {
                phase = nextWalksRight ? .walkingRight : .walkingLeft
                phaseTime = 0
            }
        case .walkingRight:
            x = min(destination ?? right, x + Self.walkSpeed * dt)
            show(.walkRight, Int(phaseTime * 8) % 6)
            let arrived = destination.map { x >= $0 } ??
                (phaseTime >= Self.walkDuration || x >= right)
            if arrived { finishWalk(wasRight: true) }
        case .walkingLeft:
            x = max(destination ?? left, x - Self.walkSpeed * dt)
            show(.walkLeft, Int(phaseTime * 8) % 6)
            let arrived = destination.map { x <= $0 } ??
                (phaseTime >= Self.walkDuration || x <= left)
            if arrived { finishWalk(wasRight: false) }
        }
    }
}
