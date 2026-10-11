import Testing
@testable import TokenCatsCore

struct LanguageSelectionTests {
    @Test func chosenLanguageWinsWhenBundled() {
        #expect(LanguageSelection.resolve(selection: "ko", available: ["en", "ko"], preferred: ["en"]) == "ko")
    }

    @Test func unknownChoiceFallsBackToEnglish() {
        #expect(LanguageSelection.resolve(selection: "ja", available: ["en", "ko"], preferred: ["ko"]) == "en")
    }

    @Test func systemFollowsTheFirstPreferredLanguageTheBundleHas() {
        #expect(LanguageSelection.resolve(selection: "system", available: ["en", "ko"], preferred: ["fr-FR", "ko-KR"]) == "ko")
        #expect(LanguageSelection.resolve(selection: "system", available: ["en", "ko"], preferred: ["fr-FR"]) == "en")
        #expect(LanguageSelection.resolve(selection: "system", available: [], preferred: ["ko-KR"]) == "en")
    }
}
