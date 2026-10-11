import Foundation

/// The words for each kind of upload problem, in the app's language.
extension ProfileSyncProblem {
    var message: LocalizedStringResource {
        switch self {
        case .reconnect: return "Connection expired. Connect again"
        case .repoMissing: return "Could not find the profile repo"
        case .readmeTooLarge: return "TokenCats can't edit a README over 1 MB"
        case .rateLimited: return "GitHub is limiting requests for now"
        case .cardTooLarge: return "The card is too big to upload (over 2 MB)"
        case .offline: return "Can't reach GitHub. Check your connection"
        case .github(let status): return "GitHub returned an error (HTTP \(status))"
        case .other: return "Something went wrong"
        }
    }
}
