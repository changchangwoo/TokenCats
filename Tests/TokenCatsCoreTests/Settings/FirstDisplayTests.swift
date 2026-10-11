import Testing
@testable import TokenCatsCore

struct FirstDisplayTests {
    /// A MacBook with its menu bar moved to an external monitor still starts on its own screen, where the notch is.
    @Test func prefersTheBuiltInDisplay() {
        let displays = [FirstDisplay.Candidate(uuid: "external", isBuiltIn: false, isMain: true),
                        FirstDisplay.Candidate(uuid: "macbook", isBuiltIn: true, isMain: false)]
        #expect(FirstDisplay.pick(displays) == "macbook")
    }

    @Test func withoutABuiltInDisplayTheMainOneWins() {
        let displays = [FirstDisplay.Candidate(uuid: "left", isBuiltIn: false, isMain: false),
                        FirstDisplay.Candidate(uuid: "right", isBuiltIn: false, isMain: true)]
        #expect(FirstDisplay.pick(displays) == "right")
        #expect(FirstDisplay.pick([FirstDisplay.Candidate(uuid: "only", isBuiltIn: false, isMain: false)]) == "only")
        #expect(FirstDisplay.pick([]) == nil)
    }
}
