import Foundation

/// The one part of the user's profile README the app writes: an image line between two markers.
/// Everything outside the markers is the user's and is never changed.
enum ProfileReadme {
    static let start = "<!-- tokencats:start -->"
    static let end = "<!-- tokencats:end -->"
    /// Blocks written before the TokenCats rename are found, replaced and removed the same way.
    private static let markerPairs = [(start, end), (LegacyIdentity.readmeStart, LegacyIdentity.readmeEnd)]
    static let branch = "catroom"
    static let path = "catroom.svg"

    /// Public raw URL on the dedicated branch; profile READMEs only show for public repos.
    static func imageURL(owner: String, repo: String) -> String {
        "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(path)"
    }

    /// No height: the card has a fixed aspect ratio, so the README width sizes all of it.
    static func block(owner: String, repo: String) -> String {
        [start,
         #"<img src="\#(imageURL(owner: owner, repo: repo))" width="100%" alt="My cat room and agent activity">"#,
         end].joined(separator: "\n")
    }

    /// Whether the README already carries our block, under the current or the pre-TokenCats markers.
    static func hasBlock(_ readme: String) -> Bool {
        markedRange(in: readme) != nil
    }

    /// Replaces what is between the markers, or puts the block at the top followed by a blank line.
    static func upsert(_ readme: String, owner: String, repo: String) -> String {
        let block = block(owner: owner, repo: repo)
        if let range = markedRange(in: readme) {
            return readme.replacingCharacters(in: range, with: block)
        }
        return readme.isEmpty ? block + "\n" : block + "\n\n" + readme
    }

    /// Takes the block out together with up to two newlines right after it (its line end and one blank line).
    static func remove(_ readme: String) -> String {
        guard let range = markedRange(in: readme) else { return readme }
        var upper = range.upperBound
        for _ in 0..<2 where upper < readme.endIndex && readme[upper] == "\n" {
            upper = readme.index(after: upper)
        }
        return readme.replacingCharacters(in: range.lowerBound..<upper, with: "")
    }

    private static func markedRange(in readme: String) -> Range<String.Index>? {
        for (start, end) in markerPairs {
            if let open = readme.range(of: start),
               let close = readme.range(of: end, range: open.upperBound..<readme.endIndex) {
                return open.lowerBound..<close.upperBound
            }
        }
        return nil
    }
}
