import Foundation

/// A cat's name as shown: its coat, numbered when the household has more than one of that coat.
struct CatDisplayName: Equatable, Sendable {
    let coat: String
    /// 1-based adoption order among cats of the same coat; nil when it is the only one.
    let ordinal: Int?
}

enum CatNames {
    /// The only cheese cat is "cheese"; with two, the first adopted is "cheese 1" and the next "cheese 2".
    static func display(_ cat: CatResidentRecord, in household: CatHousehold) -> CatDisplayName {
        let sameCoat = household.residents.filter { $0.coat == cat.coat }
        guard sameCoat.count > 1, let index = sameCoat.firstIndex(where: { $0.id == cat.id }) else {
            return CatDisplayName(coat: cat.coat, ordinal: nil)
        }
        return CatDisplayName(coat: cat.coat, ordinal: index + 1)
    }
}
