import Foundation
import Testing
@testable import TokenCatsCore

struct UsageDashboardTests {
    @Test func countdownKeepsOnlyTheUnitsWorthSaying() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Plain numbers only: arithmetic in these cases made Swift 6.1 give up type-checking them.
        let cases: [(TimeInterval, ResetCountdown)] = [
            (3_540, ResetCountdown(days: 0, hours: 0, minutes: 59)),
            (3_600, ResetCountdown(days: 0, hours: 1, minutes: 0)),
            (5_400, ResetCountdown(days: 0, hours: 1, minutes: 30)),
            (86_400, ResetCountdown(days: 1, hours: 0, minutes: 0)),
            (184_800, ResetCountdown(days: 2, hours: 3, minutes: 0)),  // 2d 3h 20m
            (20, ResetCountdown(days: 0, hours: 0, minutes: 1)),
        ]
        for (seconds, countdown) in cases {
            #expect(UsageDashboard.countdown(until: now.addingTimeInterval(seconds), now: now) == countdown)
        }
    }

    @Test func tiersChangeAtSeventyAndNinety() {
        #expect([69.9, 70, 89.9, 90].map(UsageDashboard.tier) == [.normal, .warning, .warning, .critical])
    }
}
