import Foundation

/// A theme's wall and floor pictures as PNG bytes, embedded in the profile card.
struct RoomArtPNGs: Sendable {
    let wall: Data
    let floor: Data
}
