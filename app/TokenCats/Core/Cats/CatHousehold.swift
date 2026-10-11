import Foundation

/// One cat the user owns. `coat` names its art in `cat-assets.json`; `id` is unique per cat,
/// so two cats may share a coat. `inRoom` is false while the cat waits in storage.
struct CatResidentRecord: Codable, Equatable, Sendable {
    let id: String
    let coat: String
    var inRoom: Bool

    init(id: String, coat: String, inRoom: Bool = true) {
        self.id = id
        self.coat = coat
        self.inRoom = inRoom
    }

    /// Files written before storage existed have no `inRoom`: every cat lived in the room.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        coat = try container.decode(String.self, forKey: .coat)
        inRoom = try container.decodeIfPresent(Bool.self, forKey: .inRoom) ?? true
    }
}

/// Every cat the user owns, saved across launches. Up to four live in the room; storage has no limit.
struct CatHousehold: Codable, Equatable, Sendable {
    static let roomCapacity = 4

    enum MoveError: Error, Equatable {
        case unknownCat, roomFull, lastCatInRoom, saveFailed, notASwap
    }

    private(set) var residents: [CatResidentRecord]

    /// Drops duplicate ids and sends room cats past the room's capacity to storage; no cat is ever dropped.
    init(residents: [CatResidentRecord]) {
        var seen = Set<String>()
        var roomCount = 0
        self.residents = residents.filter { seen.insert($0.id).inserted }
            .map { record in
                var record = record
                if record.inRoom {
                    if roomCount < Self.roomCapacity { roomCount += 1 } else { record.inRoom = false }
                }
                return record
            }
    }

    var roomResidents: [CatResidentRecord] { residents.filter(\.inRoom) }
    var storedResidents: [CatResidentRecord] { residents.filter { !$0.inRoom } }
    var isRoomFull: Bool { roomResidents.count >= Self.roomCapacity }
    /// Adds a cat with a new unique id: into the room while there is space, otherwise into storage.
    @discardableResult
    mutating func adopt(coat: String) -> CatResidentRecord {
        var number = residents.filter { $0.coat == coat }.count + 1
        while residents.contains(where: { $0.id == "\(coat)-\(number)" }) { number += 1 }
        let record = CatResidentRecord(id: "\(coat)-\(number)", coat: coat, inRoom: !isRoomFull)
        residents.append(record)
        return record
    }

    /// Moves a cat between the room and storage. The room never goes over its capacity or under one.
    mutating func move(id: String, toRoom: Bool) throws {
        guard let index = residents.firstIndex(where: { $0.id == id }) else { throw MoveError.unknownCat }
        guard residents[index].inRoom != toRoom else { return }
        if toRoom {
            guard !isRoomFull else { throw MoveError.roomFull }
        } else {
            guard roomResidents.count > 1 else { throw MoveError.lastCatInRoom }
        }
        residents[index].inRoom = toRoom
    }

    /// Lets a cat go for good: it leaves the household and is not coming back. The room never goes under one,
    /// so the last cat in the room stays.
    mutating func release(id: String) throws {
        guard let index = residents.firstIndex(where: { $0.id == id }) else { throw MoveError.unknownCat }
        if residents[index].inRoom { guard roomResidents.count > 1 else { throw MoveError.lastCatInRoom } }
        residents.remove(at: index)
    }

    /// A full room's way to bring a stored cat in: it takes the place of `roomID`, which goes to storage.
    mutating func swap(roomID: String, storedID: String) throws {
        guard let room = residents.firstIndex(where: { $0.id == roomID }),
              let stored = residents.firstIndex(where: { $0.id == storedID }) else { throw MoveError.unknownCat }
        guard residents[room].inRoom, !residents[stored].inRoom else { throw MoveError.notASwap }
        residents[room].inRoom = false
        residents[stored].inRoom = true
    }

    /// A first launch starts with one cat whose coat the caller picks.
    static func load(from file: JSONFile<CatHousehold>, firstCoat: () -> String) -> CatHousehold {
        if let saved = file.load() { return CatHousehold(residents: saved.residents) }
        var first = CatHousehold(residents: [])
        first.adopt(coat: firstCoat())
        file.save(first)
        return first
    }
}

/// Everything one cat is doing right now.
struct CatResident: Sendable {
    let record: CatResidentRecord
    fileprivate(set) var motion: CatRoomMotion
    fileprivate(set) var hearts = CatHeartInteraction()
    fileprivate(set) var petting = CatPettingInteraction()
    fileprivate(set) var yOffset = 0.0

    var id: String { record.id }
    var coat: String { record.coat }
}

/// What to draw for one cat this frame.
struct CatSceneCat: Equatable, Sendable {
    let id: String
    let coat: String
    let x: Double
    let yOffset: Double
    let clip: CatClip
    let clipIndex: Int
    let petFrame: Int?
    let heartProgress: Double?
    let heartSide: CatHeartSide
}

/// The room holds up to four cats; it draws only the ones that fit with breathing space.
struct CatRoom: Sendable {
    /// The widest current coat/pose is 88pt; 12pt keeps bodies from touching.
    static let minCenterSpacing = 100.0
    /// A full room fits on the notch floor; narrower rooms still hide the cats that do not fit.
    static let maxVisible = CatHousehold.roomCapacity
    private static let edgeInset = 48.0

    private(set) var residents: [CatResident]
    private var placedWidth: Double?
    private var visibleCount = 0
    private var roamLeft = 48.0
    private var roamRight = 48.0
    private var activeSwap: (first: Int, second: Int)?
    var hiddenCount: Int { max(0, residents.count - visibleCount) }

    init(household: CatHousehold) {
        let records = household.roomResidents
        let count = records.count
        residents = records.enumerated().map { index, record in
            // Stagger rests so housemates groom and walk at different moments.
            CatResident(record: record,
                        motion: CatRoomMotion(x: 80, restOffset: Double(index) * 10.0 / Double(max(1, count)),
                                              walksRightFirst: index % 2 == 0, rhythmSeed: index))
        }
    }

    /// Advances every cat. A cat being petted holds still; the others carry on.
    mutating func step(dt: Double, now: Double, width: Double) -> [CatSceneCat] {
        placeIfNeeded(width: width)
        let visible = 0..<visibleCount
        for index in visible {
            let petFrame = residents[index].petting.frame(at: now)
            if petFrame == nil {
                var proposed = residents[index].motion
                let wasWalking = proposed.isWalking
                proposed.step(dt: dt, width: width)
                if !wasWalking && proposed.isWalking {
                    if visible.contains(where: { $0 != index && residents[$0].motion.isWalking }) {
                        proposed.waitForClearLane()
                    } else if let requested = proposed.plannedWalkEndpoint(width: width),
                              let destination = freeDestination(from: proposed.x,
                                                                 toward: requested, except: index) {
                        proposed.planWalk(to: destination)
                    } else if let requested = proposed.plannedWalkEndpoint(width: width),
                              let partner = swapPartner(for: index, toward: requested, now: now) {
                        let originalX = proposed.x
                        proposed.planWalk(to: residents[partner].motion.x)
                        residents[partner].motion.planWalk(to: originalX)
                        activeSwap = (first: index, second: partner)
                    } else {
                        proposed.yieldToNeighbor()
                    }
                }
                residents[index].motion = proposed
            }
        }
        if let swap = activeSwap,
           !residents[swap.first].motion.isWalking && !residents[swap.second].motion.isWalking {
            activeSwap = nil
        }
        for index in visible {
            residents[index].yOffset = 0
        }
        return residents.prefix(visibleCount).map { cat in
            CatSceneCat(id: cat.id, coat: cat.coat, x: cat.motion.x, yOffset: cat.yOffset,
                        clip: cat.motion.clip, clipIndex: cat.motion.clipIndex,
                        petFrame: cat.petting.frame(at: now),
                        heartProgress: cat.hearts.progress(at: now), heartSide: cat.hearts.side)
        }
    }

    /// The cat under the point. Later residents are drawn on top, so they win when cats overlap.
    func catIndex(at point: RoomPoint, baseline: Double) -> Int? {
        (0..<visibleCount)
            .filter { residents[$0].motion.isNear(point, baseline: baseline) }
            .max()
    }

    /// Pets the front-most cat under the point; returns its id.
    @discardableResult
    mutating func pet(at now: Double, point: RoomPoint, baseline: Double) -> String? {
        guard let index = catIndex(at: point, baseline: baseline),
              residents[index].petting.touch(at: now, point: point, cat: residents[index].motion,
                                             baseline: baseline)
        else { return nil }
        _ = residents[index].hearts.tap(at: now, point: point, cat: residents[index].motion,
                                        baseline: baseline)
        return residents[index].id
    }

    mutating func endPet(at now: Double) {
        for index in residents.indices { residents[index].petting.end(at: now) }
    }

    /// Takes in the room's cats after an adoption or a move. Cats already here keep their spot and what they
    /// are doing; cats that became visible land on the freest spot; cats that left disappear.
    mutating func sync(_ household: CatHousehold) {
        let records = household.roomResidents
        let incomingIDs = Set(records.map(\.id))
        let kept = residents.filter { incomingIDs.contains($0.id) }
        let keptIDs = Set(kept.map(\.id))
        let arriving = records.filter { !keptIDs.contains($0.id) }
        guard kept.count != residents.count || !arriving.isEmpty else { return }
        let total = kept.count + arriving.count
        let newcomers = arriving.enumerated().map { offset, record in
            let index = kept.count + offset
            return CatResident(record: record,
                               motion: CatRoomMotion(x: 80, restOffset: Double(index) * 10.0 / Double(max(1, total)),
                                                     walksRightFirst: index % 2 == 0, rhythmSeed: index))
        }
        let previouslyVisible = Set(residents.prefix(visibleCount).map(\.id))
        residents = kept + newcomers
        activeSwap = nil
        guard let width = placedWidth else { return }
        refit(width: width, previouslyVisible: previouslyVisible)
    }

    /// Spreads cats evenly across the floor the first time the width is known.
    private mutating func placeIfNeeded(width: Double) {
        guard width > 0, placedWidth != width else { return }
        placedWidth = width
        let left = Self.edgeInset, right = max(left, width - Self.edgeInset)
        let available = right - left
        let fitting = max(1, Int(available / Self.minCenterSpacing) + 1)
        visibleCount = min(residents.count, fitting, Self.maxVisible)
        guard visibleCount > 0 else { return }
        if visibleCount == 1 {
            let middle = max(left, width / 2)
            residents[0].motion.place(x: middle)
            roamLeft = max(left, middle - 100)
            roamRight = min(right, middle + 100)
        } else {
            let spacing = min(130, available / Double(visibleCount - 1))
            let first = width / 2 - spacing * Double(visibleCount - 1) / 2
            for index in 0..<visibleCount {
                residents[index].motion.place(x: first + Double(index) * spacing)
            }
            roamLeft = max(left, first - 100)
            roamRight = min(right, first + spacing * Double(visibleCount - 1) + 100)
        }
    }

    /// Recounts who fits after `sync`. Cats that were on screen stay put; the rest are placed one by one
    /// where they are farthest from everyone already standing.
    private mutating func refit(width: Double, previouslyVisible: Set<String>) {
        let left = Self.edgeInset, right = max(left, width - Self.edgeInset)
        let fitting = max(1, Int((right - left) / Self.minCenterSpacing) + 1)
        visibleCount = min(residents.count, fitting, Self.maxVisible)
        guard visibleCount > 0 else { return }
        let visible = 0..<visibleCount
        var occupied = visible.filter { previouslyVisible.contains(residents[$0].id) }.map { residents[$0].motion.x }
        if occupied.isEmpty {
            placedWidth = nil
            placeIfNeeded(width: width)
            return
        }
        for index in visible where !previouslyVisible.contains(residents[index].id) {
            let spot = Self.landingSpot(left: left, right: right, occupied: occupied)
            residents[index].motion.place(x: spot)
            occupied.append(spot)
        }
        roamLeft = max(left, occupied.min()! - 100)
        roamRight = min(right, occupied.max()! + 100)
    }

    /// The floor position farthest from every occupied spot, nearest the middle on ties.
    private static func landingSpot(left: Double, right: Double, occupied: [Double]) -> Double {
        let middle = (left + right) / 2
        var best = middle, bestGap = -1.0
        for candidate in stride(from: left, through: right, by: 10) {
            let gap = occupied.map { abs($0 - candidate) }.min() ?? .infinity
            if gap > bestGap || (gap == bestGap && abs(candidate - middle) < abs(best - middle)) {
                best = candidate
                bestGap = gap
            }
        }
        return best
    }

    /// Look beyond occupied positions for a safe landing. Cats may overlap briefly while crossing.
    private func freeDestination(from x: Double, toward requested: Double, except moving: Int) -> Double? {
        let preferred = requested >= x ? 1.0 : -1.0
        for direction in [preferred, -preferred] {
            let boundary = direction > 0 ? roamRight : roamLeft
            var candidate = min(roamRight, max(roamLeft, x + direction * 60))
            while (boundary - candidate) * direction >= -0.000_001 &&
                  (candidate - x) * direction >= 20 {
                if (0..<visibleCount).allSatisfy({ index in
                    index == moving || abs(candidate - residents[index].motion.x) >= Self.minCenterSpacing
                }) { return candidate }
                candidate += direction * 10
            }
        }
        return nil
    }

    /// When every landing spot is occupied, two adjacent cats trade places on the same floor.
    private func swapPartner(for moving: Int, toward requested: Double, now: Double) -> Int? {
        guard activeSwap == nil else { return nil }
        let order = (0..<visibleCount).sorted { residents[$0].motion.x < residents[$1].motion.x }
        guard let rank = order.firstIndex(of: moving) else { return nil }
        let preferred = requested >= residents[moving].motion.x ? 1 : -1
        for direction in [preferred, -preferred] {
            let neighbor = rank + direction
            guard order.indices.contains(neighbor) else { continue }
            let partner = order[neighbor]
            if !residents[partner].motion.isWalking && residents[partner].petting.frame(at: now) == nil {
                return partner
            }
        }
        return nil
    }
}
