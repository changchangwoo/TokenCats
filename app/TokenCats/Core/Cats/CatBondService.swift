import Foundation

/// The only writer of `bonds.json`. Not thread-safe: run it on the churu tracker's queue like `StoreService`, so a
/// treat credits the bond on the same queue that spent the churu. Nothing changes unless the file is written.
final class CatBondService: @unchecked Sendable {
    private let file: JSONFile<CatBondBook>
    private(set) var book: CatBondBook

    init(file: JSONFile<CatBondBook>) {
        self.file = file
        book = file.load() ?? CatBondBook()
    }

    @discardableResult
    func pet(_ id: String) -> CatBondBook { change { $0.pet(id) } }

    @discardableResult
    func treat(_ id: String) -> CatBondBook { change { $0.treat(id) } }

    @discardableResult
    func accruePresence(for ids: [String], now: Date = Date(), calendar: Calendar = .current) -> CatBondBook {
        change { $0.accruePresence(for: ids, now: now, calendar: calendar) }
    }

    @discardableResult
    func forget(_ id: String) -> CatBondBook { change { $0.forget(id) } }

    /// Applies a change and saves it. An unchanged book writes nothing; a failed save keeps the old book.
    private func change(_ edit: (inout CatBondBook) -> Void) -> CatBondBook {
        var next = book
        edit(&next)
        guard next != book else { return book }
        guard file.save(next) else { return book }
        book = next
        return book
    }
}
