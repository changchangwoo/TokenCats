import Foundation
import Testing
@testable import TokenCatsCore

struct UsagePresentationTests {
    @Test func newProviderUsesTheSameSummaryAndDetails() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sources = [
            UsageSource(id: "claude", name: "Claude", state: .ready, metrics: [
                UsageMetric(kind: .fiveHour, value: "64%", fraction: 0.64, resetsAt: now.addingTimeInterval(3_600)),
                UsageMetric(kind: .weekly, value: "28%", fraction: 0.28, resetsAt: now.addingTimeInterval(86_400)),
            ]),
            UsageSource(id: "gemini", name: "Gemini", state: .ready, metrics: [
                UsageMetric(kind: .daily, value: "16/100", fraction: 0.16, resetsAt: nil),
                UsageMetric(kind: .requests, value: "42/100", fraction: 0.42, resetsAt: nil),
                UsageMetric(kind: .weekly, value: "82%", fraction: 0.82, resetsAt: nil),
            ]),
        ]
        let cards = UsagePresentation.cards(sources: sources, settings: .default, now: now)
        #expect(cards.map(\.id) == ["claude", "gemini"])
        #expect(cards[1].summary == .metric(.weekly, value: "82%"))
        #expect(cards[1].details.count == 3)
        #expect(cards[1].details[0].value == "16/100")
        #expect(cards[1].details[0].notes.isEmpty)
    }

    @Test func valueIsSplitFromItsNoteForTheLedgerRow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = UsageSource(id: "claude", name: "Claude", state: .ready, metrics: [
            UsageMetric(kind: .fiveHour, value: "7%", fraction: 0.07, resetsAt: now.addingTimeInterval(6_540)),
        ])
        let detail = UsagePresentation.cards(sources: [source], settings: .default, now: now)[0].details[0]
        #expect(detail.value == "7%")
        #expect(detail.notes == [.resetsIn(ResetCountdown(days: 0, hours: 1, minutes: 49))])
        var hidden = HomeDisplaySettings.default
        hidden.showUsageValues = false
        let quiet = UsagePresentation.cards(sources: [source], settings: hidden, now: now)[0].details[0]
        #expect(quiet.value == nil)
        #expect(quiet.notes == [.resetsIn(ResetCountdown(days: 0, hours: 1, minutes: 49))])
    }

    @Test func settingsHideAndOrderProvidersWithoutChangingTheirData() {
        let sources = [
            UsageSource(id: "claude", name: "Claude", state: .waiting, metrics: []),
            UsageSource(id: "codex", name: "Codex", state: .waiting, metrics: []),
            UsageSource(id: "gemini", name: "Gemini", state: .waiting, metrics: []),
        ]
        var settings = HomeDisplaySettings.default
        settings.providerOrder = ["gemini", "codex"]
        settings.hiddenProviderIDs = ["claude"]
        let cards = UsagePresentation.cards(sources: sources, settings: settings, now: Date())
        #expect(cards.map(\.id) == ["gemini", "codex"])
    }

    @Test func expiredWindowIsNotShownAsAnActiveLimit() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = UsageSource(id: "codex", name: "Codex", state: .ready, metrics: [
            UsageMetric(kind: .fiveHour, value: "96%", fraction: 0.96,
                        resetsAt: now.addingTimeInterval(-60)),
            UsageMetric(kind: .weekly, value: "35%", fraction: 0.35,
                        resetsAt: now.addingTimeInterval(86_400)),
        ])
        let card = UsagePresentation.cards(sources: [source], settings: .default, now: now)[0]
        #expect(card.summary == .metric(.weekly, value: "35%"))
        #expect(card.details[0].value == nil)
        #expect(card.details[0].notes == [.reset])
        #expect(card.details[0].fraction == 0)
    }

    @Test func displaySwitchesHideValuesBarsAndResetTime() {
        var settings = HomeDisplaySettings.default
        settings.showUsageValues = false
        settings.showUsageBars = false
        settings.showResetTime = false
        let source = UsageSource(id: "gemini", name: "Gemini", state: .ready, metrics: [
            UsageMetric(kind: .daily, value: "21/100", fraction: 0.21,
                        resetsAt: Date(timeIntervalSince1970: 1_800_003_600)),
        ])
        let card = UsagePresentation.cards(sources: [source], settings: settings,
                                           now: Date(timeIntervalSince1970: 1_800_000_000))[0]
        #expect(card.summary == .metric(.daily, value: nil))
        #expect(card.details[0].value == nil)
        #expect(card.details[0].notes.isEmpty)
        #expect(card.details[0].fraction == nil)
    }

    @Test func uiSettingsFileIsCreatedOnceAndKeepsUserChoices() throws {
        let root = try makeTempDirectory()
        let file = JSONFile<UIDisplaySettings>(url: root.appendingPathComponent("ui-display.json"))
        let first = UIDisplaySettings.load(from: file)
        #expect(first == .default)
        #expect(file.load() == .default)
        var edited = first
        edited.home.hiddenProviderIDs = ["codex"]
        edited.home.showResetTime = false
        file.save(edited)
        #expect(UIDisplaySettings.load(from: file) == edited)
    }

    @Test func olderUiSettingsGainNewDisplaySwitches() throws {
        let data = Data(#"{"schemaVersion":1,"home":{"showBalance":false,"hiddenProviderIDs":["codex"]}}"#.utf8)
        let decoded = try JSONDecoder().decode(UIDisplaySettings.self, from: data)
        #expect(decoded.home.showBalance == false)
        #expect(decoded.home.hiddenProviderIDs == ["codex"])
        #expect(decoded.home.showWeeklyChart && decoded.home.showContributionGraph)
    }
}
