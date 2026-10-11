import Foundation
import Testing
@testable import TokenCatsCore

private let seoul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}()
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    seoul.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}
private func connected(uploaded: Date?, attempted: Date? = nil, error: String? = nil) -> ProfileSyncState {
    ProfileSyncState(method: .gh, owner: "neko", repo: "neko", lastDigest: uploaded == nil ? nil : "d",
                     lastUploadAt: uploaded, lastAttemptAt: attempted ?? uploaded, lastError: error, readmeInstalled: true)
}

struct ProfileSyncPolicyTests {
    @Test func nothingWhileDisconnected() {
        #expect(!ProfileSyncPolicy.shouldSync(ProfileSyncState(), now: at(10, 12), catsModified: at(10, 11), calendar: seoul))
    }

    @Test func firstUploadRightAway() {
        #expect(ProfileSyncPolicy.shouldSync(connected(uploaded: nil), now: at(10, 12), catsModified: nil, calendar: seoul))
    }

    @Test func onceADay() {
        let state = connected(uploaded: at(10, 9))
        #expect(!ProfileSyncPolicy.shouldSync(state, now: at(10, 23, 59), catsModified: nil, calendar: seoul))
        #expect(ProfileSyncPolicy.shouldSync(state, now: at(11, 0, 1), catsModified: nil, calendar: seoul))
    }

    @Test func rightAfterTheCatsChange() {
        let state = connected(uploaded: at(10, 9))
        #expect(ProfileSyncPolicy.shouldSync(state, now: at(10, 12), catsModified: at(10, 11), calendar: seoul))
        #expect(!ProfileSyncPolicy.shouldSync(state, now: at(10, 12), catsModified: at(10, 8), calendar: seoul))
    }

    @Test func rightAfterTheBackgroundChanges() {
        var state = connected(uploaded: at(10, 9))
        state.lastThemeID = "cozy"
        #expect(ProfileSyncPolicy.shouldSync(state, now: at(10, 12), catsModified: nil, themeID: "night", calendar: seoul))
        #expect(!ProfileSyncPolicy.shouldSync(state, now: at(10, 12), catsModified: nil, themeID: "cozy", calendar: seoul))
    }

    @Test func failuresRetryAfterAnHour() {
        let state = connected(uploaded: at(10, 9), attempted: at(10, 11), error: "offline")
        #expect(!ProfileSyncPolicy.shouldSync(state, now: at(10, 11, 59), catsModified: nil, calendar: seoul))
        #expect(ProfileSyncPolicy.shouldSync(state, now: at(10, 12), catsModified: nil, calendar: seoul))
    }

    @Test func reconnectNeededStopsSyncing() {
        var state = connected(uploaded: at(10, 9), attempted: at(10, 9), error: ProfileSyncState.reconnectNeeded)
        #expect(!ProfileSyncPolicy.shouldSync(state, now: at(12, 9), catsModified: at(11, 9), calendar: seoul))
        state.lastError = nil
        #expect(ProfileSyncPolicy.shouldSync(state, now: at(12, 9), catsModified: nil, calendar: seoul))
    }

    @Test func stateRoundTripsThroughJSON() throws {
        let state = connected(uploaded: at(10, 9))
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(ProfileSyncState.self, from: data) == state)
    }
}
