import SwiftUI

/// The words for props and the places they go.
extension RoomProp {
    var title: LocalizedStringResource {
        switch self {
        case .calendar: return "Churu calendar"
        case .hideCrate: return "Hiding box"
        case .catTower: return "Cat tower"
        case .yarnBall: return "Yarn ball"
        }
    }
}

extension RoomSlot {
    var title: LocalizedStringResource {
        switch self {
        case .wallLeft: return "Left wall"
        case .floorLeft: return "Left floor"
        case .floorMidRight: return "Middle floor"
        case .floorRight: return "Right floor"
        }
    }
}
