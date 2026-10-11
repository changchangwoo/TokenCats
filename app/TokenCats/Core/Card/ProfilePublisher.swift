import Foundation

enum PublishResult: Equatable, Sendable {
    /// The card is the same as the last upload; nothing was sent.
    case unchanged
    case uploaded(digest: String, commit: String)
}

/// Puts the profile card on the `catroom` branch as a single parentless commit, skipping identical cards.
struct ProfilePublisher: Sendable {
    let api: GitHubAPI

    /// Change detection only (not security): FNV-1a over the bytes, plus the length.
    static func digest(_ svg: String) -> String {
        let bytes = Array(svg.utf8)
        let hash = bytes.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        return String(format: "%016llx-%d", hash, bytes.count)
    }

    func publish(svg: String, owner: String, repo: String, lastDigest: String?) async throws -> PublishResult {
        let digest = Self.digest(svg)
        if digest == lastDigest { return .unchanged }
        let commit = try await api.replaceBranch(owner: owner, repo: repo, branch: ProfileReadme.branch,
                                                 path: ProfileReadme.path, content: Data(svg.utf8),
                                                 message: "Update cat room")
        return .uploaded(digest: digest, commit: commit)
    }
}
