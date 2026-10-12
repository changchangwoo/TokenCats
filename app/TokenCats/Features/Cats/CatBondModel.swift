import Combine
import SwiftUI

/// The cats' bond levels on the main thread. Every change runs through `CatBondService` on the churu queue (treats
/// spend churu there), and this publishes the result. Presence is credited once a minute to the cats in the room
/// for as long as the app runs, notch open or closed.
@MainActor
final class CatBondModel: ObservableObject {
    static let shared = CatBondModel()
    static let presenceInterval: TimeInterval = 60

    @Published private(set) var book: CatBondBook
    let service: CatBondService
    private var presenceLoop: Task<Void, Never>?

    private init() {
        service = CatBondService(file: DataFiles.live.bonds)
        book = service.book
    }

    func level(of id: String) -> Int { book.level(of: id) }
    func progress(of id: String) -> Double { book.progress(of: id) }

    func publish(_ book: CatBondBook) { self.book = book }

    /// One accepted heart in the room.
    func pet(_ id: String) {
        let service = service
        Task { publish(await ChuruModel.shared.perform { service.pet(id) }) }
    }

    /// Starts the presence clock. Called once at launch. A main-actor task loop like `HomeView`'s refresh loop,
    /// so there is no `Timer` closure to make `Sendable`.
    func start() {
        guard presenceLoop == nil else { return }
        presenceLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.accruePresence()
                try? await Task.sleep(for: .seconds(Self.presenceInterval))
            }
        }
    }

    /// Credits the cats in the room for the time since their last tick.
    func accruePresence(now: Date = Date()) async {
        let ids = StoreModel.shared.household.roomResidents.map(\.id)
        let service = service
        publish(await ChuruModel.shared.perform { service.accruePresence(for: ids, now: now) })
    }
}
