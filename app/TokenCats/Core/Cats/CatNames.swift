import Foundation

/// A cat's name as shown: the name the user gave it, or its coat, numbered when the household has more than one
/// of that coat.
struct CatDisplayName: Equatable, Sendable {
    let coat: String
    /// 1-based adoption order among cats of the same coat; nil when it is the only one.
    let ordinal: Int?
    /// The user's name for the cat; shown instead of the coat name when set.
    let custom: String?

    init(coat: String, ordinal: Int?, custom: String? = nil) {
        self.coat = coat
        self.ordinal = ordinal
        self.custom = custom
    }
}

enum CatNames {
    /// Longest name a cat can be given; the collection card is 84pt wide.
    static let maxNameLength = 16

    /// The only cheese cat is "cheese"; with two, the first adopted is "cheese 1" and the next "cheese 2". A cat
    /// with a given name keeps its number (the other cheese stays "cheese 2") but shows the name.
    static func display(_ cat: CatResidentRecord, in household: CatHousehold) -> CatDisplayName {
        let sameCoat = household.residents.filter { $0.coat == cat.coat }
        guard sameCoat.count > 1, let index = sameCoat.firstIndex(where: { $0.id == cat.id }) else {
            return CatDisplayName(coat: cat.coat, ordinal: nil, custom: cat.name)
        }
        return CatDisplayName(coat: cat.coat, ordinal: index + 1, custom: cat.name)
    }
}
