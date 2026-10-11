import Foundation
import Testing
@testable import TokenCatsCore

struct ProfileSyncProblemTests {
    @Test func everyFailureGetsAKindTheUserCanActOn() {
        #expect(ProfileSyncProblem(GitHubError.unauthorized) == .reconnect)
        #expect(ProfileSyncProblem(GitHubError.notFound) == .repoMissing)
        #expect(ProfileSyncProblem(GitHubError.readmeTooLarge) == .readmeTooLarge)
        #expect(ProfileSyncProblem(GitHubError.unexpected(403)) == .rateLimited)
        #expect(ProfileSyncProblem(GitHubError.unexpected(429)) == .rateLimited)
        #expect(ProfileSyncProblem(GitHubError.unexpected(502)) == .github(502))
        #expect(ProfileSyncProblem(CatRoomSVG.TooLarge(bytes: 3_000_000)) == .cardTooLarge)
        #expect(ProfileSyncProblem(URLError(.notConnectedToInternet)) == .offline)
        #expect(ProfileSyncProblem(URLError(.timedOut)) == .offline)
        #expect(ProfileSyncProblem(CocoaError(.fileReadUnknown)) == .other)
    }
}
