import Foundation

/// Short token counts for small labels.
enum TokenCount {
    /// 850 → "850", 12_300 → "12K", 3_400_000 → "3.4M", 1_200_000_000 → "1.2B".
    static func compact(_ value: Int) -> String {
        let v = Double(value)
        switch value {
        case 1_000_000_000...: return String(format: "%.1fB", v / 1_000_000_000)
        case 1_000_000...: return String(format: "%.1fM", v / 1_000_000)
        case 1_000...: return String(format: "%.0fK", v / 1_000)
        default: return "\(value)"
        }
    }

    /// `compact` with a whole-number fraction dropped: 20_000_000 → "20M". Prices are round numbers.
    static func price(_ value: Int) -> String {
        compact(value).replacingOccurrences(of: ".0M", with: "M").replacingOccurrences(of: ".0K", with: "K")
    }
}
