import Foundation

/// What the store can offer for one product right now, in the order the button shows it: the background in use,
/// one already owned, one the balance covers, or one still short of churu.
enum OfferState: Equatable, Sendable {
    case inUse
    case owned
    case affordable(price: Int)
    case short(price: Int, by: Int)

    static func of(price: Int, balance: Int, owned: Bool, inUse: Bool) -> OfferState {
        if inUse { return .inUse }
        if owned { return .owned }
        return balance >= price ? .affordable(price: price) : .short(price: price, by: price - balance)
    }
}
