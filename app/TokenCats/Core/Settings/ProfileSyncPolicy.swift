import Foundation

/// Where the profile card goes and how the last upload went; saved as `profile-sync.json`.
struct ProfileSyncState: Codable, Equatable, Sendable {
    enum Method: String, Codable, Sendable {
        /// The installed GitHub CLI's login, asked for each time and never stored.
        case gh
        /// A GitHub App user token from the device flow, kept in a file only the user can read.
        case device
    }

    /// `lastError` value for a rejected token: wait for the user to reconnect instead of retrying.
    static let reconnectNeeded = "reconnect"

    var method: Method?
    var owner: String?
    var repo: String?
    var lastDigest: String?
    var lastUploadAt: Date?
    var lastAttemptAt: Date?
    var lastError: String?
    /// How the last uploaded card's room looked (background, and whether the calendar hung); a different one means
    /// the card is out of date.
    var lastThemeID: String?
    var readmeInstalled = false

    var isConnected: Bool { method != nil && owner != nil && repo != nil }
}

/// When to upload the card again: the first time, once a new day starts, right after the cats or the background change,
/// and an hour after a failure. A rejected token waits for the user.
enum ProfileSyncPolicy {
    static let retryAfter: TimeInterval = 3_600

    static func shouldSync(_ state: ProfileSyncState, now: Date, catsModified: Date?, themeID: String? = nil,
                           mode: ProfileSyncMode = .default, calendar: Calendar) -> Bool {
        guard mode != .manual, state.isConnected, state.lastError != ProfileSyncState.reconnectNeeded else { return false }
        if state.lastError != nil, let attempted = state.lastAttemptAt {
            return now.timeIntervalSince(attempted) >= retryAfter
        }
        guard let uploaded = state.lastUploadAt else { return true }
        if !calendar.isDate(uploaded, inSameDayAs: now) { return true }
        guard mode == .changes else { return false }
        if let catsModified, catsModified > uploaded { return true }
        if let themeID, themeID != state.lastThemeID { return true }
        return false
    }
}
