import Foundation
import Testing
@testable import TokenCatsCore

struct LocalizedNameTests {
    private func decode(_ json: String) throws -> LocalizedName {
        try JSONDecoder().decode(LocalizedName.self, from: Data(json.utf8))
    }

    @Test func plainStringNamesEveryLanguage() throws {
        let name = try decode(#""밤""#)
        #expect(name.resolve(for: Locale(identifier: "en")) == "밤")
        #expect(name.resolve(for: Locale(identifier: "ko-KR")) == "밤")
    }

    @Test func picksTheLanguageThenEnglishThenAnything() throws {
        let name = try decode(#"{"en":"Night","ko":"밤"}"#)
        #expect(name.resolve(for: Locale(identifier: "ko-KR")) == "밤")
        #expect(name.resolve(for: Locale(identifier: "en-US")) == "Night")
        #expect(name.resolve(for: Locale(identifier: "fr")) == "Night")
        #expect(try decode(#"{"ko":"밤"}"#).resolve(for: Locale(identifier: "fr")) == "밤")
    }

    @Test func emptyDictionaryIsRejected() {
        #expect(throws: (any Error).self) { try decode("{}") }
    }

    @Test func roundTripsBothShapes() throws {
        for json in [#""밤""#, #"{"en":"Night","ko":"밤"}"#] {
            let name = try decode(json)
            let data = try JSONEncoder().encode(name)
            #expect(try JSONDecoder().decode(LocalizedName.self, from: data) == name)
        }
    }
}
