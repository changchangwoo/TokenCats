import Foundation
import Security

/// Where a GitHub token comes from. The gh CLI's token is asked for each time and never stored; a device-flow
/// token lives in a file only the user can read (`DataFiles.githubToken`). It used to live in the keychain, which
/// an ad-hoc signed app loses after every update; a token still there is moved to the file the first time it reads.
enum GitHubCredentials {
    private static let service = "TokenCats.github"
    private static let account = "user-token"

    static var ghPath: String? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// The registered GitHub App's client ID (`docs/setup/github-app.md`); the device-flow button hides without it.
    static var deviceClientID: String? {
        let id = AppSettings.githubAppClientID
            ?? Bundle.main.object(forInfoDictionaryKey: "NCGitHubAppClientID") as? String
        return id?.isEmpty == false ? id : nil
    }

    /// Where a device-flow user lets the GitHub App reach their profile repo. Its token only works on repos the
    /// app is installed on, so without this step every upload answers 404.
    static var appInstallURL: URL? {
        guard let slug = Bundle.main.object(forInfoDictionaryKey: "NCGitHubAppSlug") as? String, !slug.isEmpty else {
            return nil
        }
        return URL(string: "https://github.com/apps/\(slug)/installations/new")
    }

    static func token(for method: ProfileSyncState.Method) async -> String? {
        switch method {
        case .gh:
            return await Task.detached(priority: .utility) { ghToken() }.value
        case .device:
            guard let token = savedToken(), !token.isExpired(now: Date()) else { return nil }
            return token.accessToken
        }
    }

    /// `gh auth token`; nil when gh is missing or logged out.
    static func ghToken() -> String? {
        guard let path = ghPath else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "token", "--hostname", "github.com"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return process.terminationStatus == 0 && !token.isEmpty ? token : nil
        } catch {
            return nil
        }
    }

    /// False when the token could not be written; the caller reports it instead of looking connected.
    @discardableResult
    static func save(_ token: UserToken) -> Bool {
        guard DataFiles.live.githubToken.save(token) else { return false }
        deleteKeychainItem()
        return true
    }

    static func savedToken() -> UserToken? {
        if let token = DataFiles.live.githubToken.load() { return token }
        guard let legacy = keychainToken() else { return nil }
        if DataFiles.live.githubToken.save(legacy) { deleteKeychainItem() }
        return legacy
    }

    static func deleteSaved() {
        DataFiles.live.githubToken.delete()
        deleteKeychainItem()
    }

    /// A token an earlier version kept in the keychain, if this build can still read it.
    private static func keychainToken() -> UserToken? {
        var item = query
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(UserToken.self, from: data)
    }

    private static func deleteKeychainItem() {
        SecItemDelete(query as CFDictionary)
    }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
