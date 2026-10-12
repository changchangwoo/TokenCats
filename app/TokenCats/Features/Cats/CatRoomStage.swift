import Combine
import SwiftUI

/// Holds the room between frames and follows who lives in it.
@MainActor
final class CatRoomStage {
    static let shared = CatRoomStage()
    private var room: CatRoom
    private var lastTick: Date?
    private var householdChanges: AnyCancellable?
    var hiddenCount: Int { room.hiddenCount }
    /// Where the pointer is over the room, or nil. Plain storage, not published: the room view reads it once per
    /// timeline frame, so pointer motion never redraws the room on its own.
    var hoverPoint: RoomPoint?

    private init() {
        let store = StoreModel.shared
        room = CatRoom(household: Self.drawable(store.household))
        householdChanges = store.$household.dropFirst().sink { [weak self] household in
            self?.room.sync(Self.drawable(household))
        }
    }

    /// Coats without art (e.g. removed from the catalog) are left out instead of drawing nothing.
    private static func drawable(_ household: CatHousehold) -> CatHousehold {
        CatHousehold(residents: household.residents.filter { CatSprites.shared.hasArt(coat: $0.coat) })
    }

    func tick(at date: Date, width: Double) -> [CatSceneCat] {
        let delta = min(0.25, lastTick.map { max(0, date.timeIntervalSince($0)) } ?? 0)
        lastTick = date
        return room.step(dt: delta, now: date.timeIntervalSinceReferenceDate, width: width)
    }

    /// Pets the cat under the point; an accepted heart credits its bond.
    func pet(at date: Date, point: RoomPoint, baseline: Double) {
        if let id = room.pet(at: date.timeIntervalSinceReferenceDate, point: point, baseline: baseline) {
            CatBondModel.shared.pet(id)
        }
    }

    func endPet(at date: Date) { room.endPet(at: date.timeIntervalSinceReferenceDate) }

    /// Hearts for a cat that was just given a treat.
    func celebrate(id: String, at date: Date) {
        room.celebrate(id: id, at: date.timeIntervalSinceReferenceDate)
    }

    /// The front-most cat under the point, for the hover badge and the right-click menu.
    func catID(at point: RoomPoint, baseline: Double) -> String? { room.catID(at: point, baseline: baseline) }

    private var cachedScene: (height: Double, calendar: ChuruMonthCalendar?, theme: RoomTheme, decor: RoomDecor,
                              scene: CatRoomScene)?

    /// Rebuilt only when the room height, the calendar, the background or the props change, not every frame.
    func scene(height: Double, calendar: ChuruMonthCalendar?, theme: RoomTheme, decor: RoomDecor) -> CatRoomScene {
        if let cached = cachedScene, cached.height == height, cached.calendar == calendar,
           cached.decor == decor,
           cached.theme == theme { return cached.scene }
        let scene = CatRoomScene(height: height, calendarTop: 12, calendar: calendar, theme: theme,
                                 showsCalendar: decor.shows(.calendar), props: decor.shownProps)
        cachedScene = (height, calendar, theme, decor, scene)
        return scene
    }

    func pause() { lastTick = nil }
}
