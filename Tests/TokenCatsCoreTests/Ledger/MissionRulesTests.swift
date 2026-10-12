import Foundation
import Testing
@testable import TokenCatsCore

private let rules = MissionRules.standard

struct MissionRulesTests {
    @Test func threeFixedMissionsInDisplayOrder() {
        #expect(rules.missions.map(\.id) == [.checkIn, .pet, .tokens1M])
        #expect(rules.rule(.checkIn) == MissionRule(id: .checkIn, target: 1, baseReward: 50_000))
        #expect(rules.rule(.pet) == MissionRule(id: .pet, target: 1, baseReward: 50_000))
        #expect(rules.rule(.tokens1M) == MissionRule(id: .tokens1M, target: 1_000_000, baseReward: 150_000))
    }

    /// 1.0 with no streak, +0.1 per day, capped at 2.0 from the tenth day.
    @Test func multiplierGrowsByTenthsAndCapsAtTwo() {
        #expect(rules.multiplier(streak: 0) == 1.0)
        #expect(rules.multiplier(streak: 1) == 1.1)
        #expect(rules.multiplier(streak: 5) == 1.5)
        #expect(rules.multiplier(streak: 10) == 2.0)
        #expect(rules.multiplier(streak: 30) == 2.0)
        #expect(rules.multiplier(streak: -3) == 1.0)
    }

    @Test func rewardIsBaseTimesMultiplierRoundedToWholeChuru() {
        let pet = rules.rule(.pet)!
        let tokens = rules.rule(.tokens1M)!
        #expect(rules.reward(for: pet, streak: 0) == 50_000)
        #expect(rules.reward(for: pet, streak: 3) == 65_000)
        #expect(rules.reward(for: tokens, streak: 10) == 300_000)
        #expect(rules.reward(for: tokens, streak: 7) == 255_000)
    }

    /// Check-in is always ready; petting and tokens read their own progress source.
    @Test func statusesReadProgressFromTheDayAndTodayTokens() {
        let day = MissionDay(day: "2026-10-12")
        let fresh = rules.statuses(day: day, todayTokens: 0, streak: 0)
        #expect(fresh == [
            MissionStatus(id: .checkIn, progress: 1, target: 1, reward: 50_000, state: .claimable),
            MissionStatus(id: .pet, progress: 0, target: 1, reward: 50_000, state: .inProgress),
            MissionStatus(id: .tokens1M, progress: 0, target: 1_000_000, reward: 150_000, state: .inProgress),
        ])

        var petted = day
        petted.counts["pet"] = 1
        let later = rules.statuses(day: petted, todayTokens: 1_000_000, streak: 5)
        #expect(later.map(\.state) == [.claimable, .claimable, .claimable])
        #expect(later.map(\.reward) == [75_000, 75_000, 225_000])
    }

    /// A claimed mission shows what was paid, even after the streak (and so the live reward) changed.
    @Test func claimedStatusShowsTheFrozenReward() {
        var day = MissionDay(day: "2026-10-12")
        day.claimed["checkIn"] = 55_000
        let statuses = rules.statuses(day: day, todayTokens: 0, streak: 10)
        #expect(statuses[0] == MissionStatus(id: .checkIn, progress: 1, target: 1, reward: 55_000,
                                             state: .claimed(reward: 55_000)))
        #expect(statuses[1].reward == 100_000)
    }

    @Test func missionDayBonusIsTheSumOfClaims() {
        var day = MissionDay(day: "2026-10-12")
        #expect(day.bonus == 0)
        day.claimed["checkIn"] = 50_000
        day.claimed["pet"] = 55_000
        #expect(day.bonus == 105_000)
    }

    @Test func churuRulesCarryTheMissionRules() {
        #expect(ChuruRules.standard.missions == MissionRules.standard)
    }
}
