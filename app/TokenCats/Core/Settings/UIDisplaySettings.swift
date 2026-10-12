import Foundation

/// Only the companion Home UI. This file does not change notch behavior or agent integrations.
struct UIDisplaySettings: Codable, Equatable, Sendable {
    let schemaVersion: Int
    var home: HomeDisplaySettings

    static let `default` = UIDisplaySettings(schemaVersion: 1, home: .default)

    static func load(from file: JSONFile<UIDisplaySettings>) -> UIDisplaySettings {
        if let saved = file.load(), saved.schemaVersion == 1 { return saved }
        if !FileManager.default.fileExists(atPath: file.url.path) { file.save(.default) }
        return .default
    }
}

struct HomeDisplaySettings: Codable, Equatable, Sendable {
    var showBalance: Bool
    var showTodayTokens: Bool
    var showEstimatedCost: Bool
    var showStreak: Bool
    var showAdoptionProgress: Bool
    var showMissions: Bool
    var showWeeklyTokens: Bool
    var showWeeklyChart: Bool
    var showContributionGraph: Bool
    var showAgentLimits: Bool
    var showUsageValues: Bool
    var showUsageBars: Bool
    var showResetTime: Bool
    var hiddenProviderIDs: [String]
    var providerOrder: [String]

    static let `default` = HomeDisplaySettings(
        showBalance: true, showTodayTokens: true, showEstimatedCost: true,
        showStreak: true, showAdoptionProgress: true, showMissions: true,
        showWeeklyTokens: true, showWeeklyChart: true, showContributionGraph: true,
        showAgentLimits: true,
        showUsageValues: true, showUsageBars: true, showResetTime: true,
        hiddenProviderIDs: [], providerOrder: ["claude", "codex"])

    var showsChuruSummary: Bool {
        showBalance || showTodayTokens || showEstimatedCost || showStreak || showAdoptionProgress || showMissions
    }
    var showsHistory: Bool { showWeeklyTokens || showWeeklyChart || showContributionGraph }
    var showsHomeLedger: Bool { showsChuruSummary || showAgentLimits || showWeeklyTokens }
}

extension HomeDisplaySettings {
    private enum CodingKeys: String, CodingKey {
        case showBalance, showTodayTokens, showEstimatedCost, showStreak, showAdoptionProgress, showMissions
        case showWeeklyTokens, showWeeklyChart, showContributionGraph, showAgentLimits
        case showUsageValues, showUsageBars, showResetTime, hiddenProviderIDs, providerOrder
    }

    /// New display switches can be added without invalidating an older user's file.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        showBalance = try values.decodeIfPresent(Bool.self, forKey: .showBalance) ?? fallback.showBalance
        showTodayTokens = try values.decodeIfPresent(Bool.self, forKey: .showTodayTokens) ?? fallback.showTodayTokens
        showEstimatedCost = try values.decodeIfPresent(Bool.self, forKey: .showEstimatedCost)
            ?? fallback.showEstimatedCost
        showStreak = try values.decodeIfPresent(Bool.self, forKey: .showStreak) ?? fallback.showStreak
        showAdoptionProgress = try values.decodeIfPresent(Bool.self, forKey: .showAdoptionProgress)
            ?? fallback.showAdoptionProgress
        showMissions = try values.decodeIfPresent(Bool.self, forKey: .showMissions) ?? fallback.showMissions
        showWeeklyTokens = try values.decodeIfPresent(Bool.self, forKey: .showWeeklyTokens)
            ?? fallback.showWeeklyTokens
        showWeeklyChart = try values.decodeIfPresent(Bool.self, forKey: .showWeeklyChart)
            ?? fallback.showWeeklyChart
        showContributionGraph = try values.decodeIfPresent(Bool.self, forKey: .showContributionGraph)
            ?? fallback.showContributionGraph
        showAgentLimits = try values.decodeIfPresent(Bool.self, forKey: .showAgentLimits)
            ?? fallback.showAgentLimits
        showUsageValues = try values.decodeIfPresent(Bool.self, forKey: .showUsageValues) ?? fallback.showUsageValues
        showUsageBars = try values.decodeIfPresent(Bool.self, forKey: .showUsageBars) ?? fallback.showUsageBars
        showResetTime = try values.decodeIfPresent(Bool.self, forKey: .showResetTime) ?? fallback.showResetTime
        hiddenProviderIDs = try values.decodeIfPresent([String].self, forKey: .hiddenProviderIDs)
            ?? fallback.hiddenProviderIDs
        providerOrder = try values.decodeIfPresent([String].self, forKey: .providerOrder) ?? fallback.providerOrder
    }
}
