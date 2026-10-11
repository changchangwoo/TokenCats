import Foundation
import Testing
@testable import TokenCatsCore

struct SecretFileTests {
    private func permissions(_ url: URL) throws -> Int {
        try (FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    @Test func savesOnlyTheOwnerCanRead() throws {
        let dir = try makeTempDirectory()
        let file = SecretFile<UserToken>(url: dir.appendingPathComponent("github-token.json"))
        let token = UserToken(accessToken: "ghu_secret", expiresAt: Date(timeIntervalSince1970: 2_000_000_000))
        #expect(file.save(token))
        #expect(file.load() == token)
        #expect(try permissions(file.url) == 0o600)
        // Rewriting keeps it private too.
        #expect(file.save(UserToken(accessToken: "ghu_new", expiresAt: nil)))
        #expect(file.load()?.accessToken == "ghu_new")
        #expect(try permissions(file.url) == 0o600)
        file.delete()
        #expect(file.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
    }

    @Test func theTokenNeverTravelsInABackup() {
        #expect(!Backup.files.contains(DataFiles.live.githubToken.url.lastPathComponent))
    }
}
