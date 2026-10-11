import Foundation

/// What went wrong with a profile card upload, in terms the user can act on. The settings screen words each kind;
/// raw error descriptions ("TokenCats.GitHubError error 2") never reach it.
enum ProfileSyncProblem: Equatable, Sendable {
    /// The token is missing, expired or revoked.
    case reconnect
    case repoMissing
    case readmeTooLarge
    /// GitHub refused for now: rate limit or abuse protection (403, 429).
    case rateLimited
    case cardTooLarge
    case offline
    case github(Int)
    case other

    init(_ error: Error) {
        switch error {
        case GitHubError.unauthorized: self = .reconnect
        case GitHubError.notFound: self = .repoMissing
        case GitHubError.readmeTooLarge: self = .readmeTooLarge
        case GitHubError.unexpected(let status) where status == 403 || status == 429: self = .rateLimited
        case GitHubError.unexpected(let status): self = .github(status)
        case is CatRoomSVG.TooLarge: self = .cardTooLarge
        case let error as URLError where Self.offlineCodes.contains(error.code): self = .offline
        default: self = .other
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed,
    ]
}
