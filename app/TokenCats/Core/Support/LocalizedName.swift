import Foundation

/// A name from an asset file, in one language or several: `"밤"` or `{"en": "Night", "ko": "밤"}`.
/// Core keeps the data; a screen picks the language with `resolve(for:)`.
struct LocalizedName: Equatable, Sendable, Codable {
    /// Language code → name; `"*"` is a single name for every language.
    private let values: [String: String]
    private static let any = "*"

    init(_ values: [String: String]) { self.values = values }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            values = [Self.any: single]
            return
        }
        let dictionary = try container.decode([String: String].self)
        guard !dictionary.isEmpty else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "A name needs at least one language")
        }
        values = dictionary
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let single = values[Self.any], values.count == 1 { try container.encode(single) } else { try container.encode(values) }
    }

    /// The locale's language, else English, else the first language there is.
    func resolve(for locale: Locale) -> String {
        if let single = values[Self.any] { return single }
        let code = locale.language.languageCode?.identifier ?? "en"
        return values[code] ?? values["en"] ?? values.sorted { $0.key < $1.key }[0].value
    }
}
