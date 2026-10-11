import Foundation

/// How the store writes prices and odds.
enum StoreFormat {
    /// "10M", or "Free" in testing mode; for buttons and fractions where "churu" is already understood.
    static func short(_ price: Int) -> LocalizedStringResource {
        price == 0 ? "Free" : "\(TokenCount.price(price))"
    }

    /// "10M churu", or "Free" in testing mode.
    static func churu(_ price: Int) -> LocalizedStringResource {
        price == 0 ? "Free" : "\(TokenCount.price(price)) churu"
    }

    static func percent(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))%" : String(format: "%.1f%%", value)
    }
}
