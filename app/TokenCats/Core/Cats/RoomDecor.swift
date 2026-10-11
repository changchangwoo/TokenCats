import Foundation

/// A place in the room where one prop can hang or stand. Slots are fixed, so a prop never lands on a cat's face
/// or a button; a prop names its slot and the room decides where that is.
enum RoomSlot: String, Codable, CaseIterable, Sendable {
    case wallLeft
    case floorLeft
    case floorMidRight
    case floorRight


    /// Where a floor prop's centre stands, as a share of the room width, so the notch room and the wider profile
    /// card keep it in the same place beside the cats. Nil for the wall.
    var floorXFraction: Double? {
        switch self {
        case .wallLeft: return nil
        case .floorLeft: return 0.12
        case .floorMidRight: return 0.68
        case .floorRight: return 0.88
        }
    }
}

/// A prop's picture: a bundle image (`RoomArt/<image>.png` and `@2x`) drawn at `width` × `height` points, never
/// scaled, so its pixels stay sharp.
struct RoomPropArt: Equatable, Sendable {
    let image: String
    let width: Int
    let height: Int
}

/// Things that can be put up in the room or taken down. The churu calendar is the first, free and owned from
/// the start and drawn from the month's data; the others are pictures bought in the store.
enum RoomProp: String, Codable, CaseIterable, Sendable {
    case calendar
    case hideCrate
    case catTower
    case yarnBall

    var slot: RoomSlot {
        switch self {
        case .calendar: return .wallLeft
        case .hideCrate: return .floorLeft
        case .catTower: return .floorRight
        case .yarnBall: return .floorMidRight
        }
    }


    /// Nil for the calendar, which draws itself.
    var art: RoomPropArt? {
        switch self {
        case .calendar: return nil
        case .hideCrate: return RoomPropArt(image: "prop-hide-crate", width: 53, height: 44)
        case .catTower: return RoomPropArt(image: "prop-cat-tower", width: 74, height: 104)
        case .yarnBall: return RoomPropArt(image: "prop-yarn-ball", width: 30, height: 26)
        }
    }

    /// Owned from the start rather than bought.
    var isStarter: Bool { self == .calendar }
}

/// Which prop hangs in each slot. The notch room, store previews and the profile card all draw from it.
struct RoomDecor: Codable, Equatable, Sendable {
    /// Slot → prop, by raw value so the JSON stays a plain object.
    private var placed: [String: String]

    static let starter = RoomDecor(placed: [RoomSlot.wallLeft.rawValue: RoomProp.calendar.rawValue])

    private init(placed: [String: String]) { self.placed = placed }

    func prop(in slot: RoomSlot) -> RoomProp? { placed[slot.rawValue].flatMap(RoomProp.init(rawValue:)) }

    func shows(_ prop: RoomProp) -> Bool { self.prop(in: prop.slot) == prop }

    /// Everything in the room, in `RoomProp` order.
    var shownProps: [RoomProp] { RoomProp.allCases.filter(shows) }

    /// Puts `prop` up in its slot (replacing whatever hung there) or takes it down.
    mutating func set(_ prop: RoomProp, shown: Bool) {
        if shown {
            placed[prop.slot.rawValue] = prop.rawValue
        } else if shows(prop) {
            placed[prop.slot.rawValue] = nil
        }
    }
}
