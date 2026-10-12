import Foundation
import Testing
@testable import TokenCatsCore

struct UIDisplaySettingsTests {
    /// A ui-display.json written before missions existed keeps the section on.
    @Test func anOlderFileShowsMissionsByDefault() throws {
        let json = """
        {"schemaVersion":1,"home":{"showBalance":true,"showTodayTokens":false,"showEstimatedCost":true,
         "showStreak":true,"showAdoptionProgress":true,"showWeeklyTokens":true,"showWeeklyChart":true,
         "showContributionGraph":true,"showAgentLimits":true,"showUsageValues":true,"showUsageBars":true,
         "showResetTime":true,"hiddenProviderIDs":[],"providerOrder":["claude","codex"]}}
        """
        let settings = try JSONDecoder().decode(UIDisplaySettings.self, from: Data(json.utf8))
        #expect(settings.home.showMissions)
        #expect(!settings.home.showTodayTokens)
    }

    @Test func showMissionsRoundTrips() throws {
        var settings = UIDisplaySettings.default
        settings.home.showMissions = false
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(UIDisplaySettings.self, from: data) == settings)
    }
}
