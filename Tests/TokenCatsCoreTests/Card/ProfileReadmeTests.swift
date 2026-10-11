import Testing
@testable import TokenCatsCore

struct ProfileReadmeTests {
    private let block = ProfileReadme.block(owner: "neko", repo: "neko")

    @Test func cardLineUsesTheCatroomBranch() {
        #expect(ProfileReadme.imageURL(owner: "neko", repo: "neko")
                == "https://raw.githubusercontent.com/neko/neko/catroom/catroom.svg")
        #expect(block == """
        <!-- tokencats:start -->
        <a href="https://github.com/changchangwoo/tokenCats"><img src="https://raw.githubusercontent.com/neko/neko/catroom/catroom.svg" width="100%" alt="My cat room and agent activity"></a>
        <!-- tokencats:end -->
        """)
    }

    /// GitHub wraps a bare image in a link to itself; ours must lead to the project instead.
    @Test func cardLinksToTheProject() {
        #expect(block.contains(#"<a href="https://github.com/changchangwoo/tokenCats"><img "#))
        #expect(block.contains("></a>\n"))
    }

    @Test func insertsAtTheTopWhenThereAreNoMarkers() {
        let readme = "# Hi, I'm neko\n\nI build things.\n"
        #expect(ProfileReadme.upsert(readme, owner: "neko", repo: "neko") == block + "\n\n" + readme)
        #expect(ProfileReadme.upsert("", owner: "neko", repo: "neko") == block + "\n")
    }

    @Test func replacesOnlyBetweenTheMarkers() {
        let old = "intro\n\n<!-- tokencats:start -->\nold line\n<!-- tokencats:end -->\n\noutro  \n"
        #expect(ProfileReadme.upsert(old, owner: "neko", repo: "neko") == "intro\n\n" + block + "\n\noutro  \n")
    }

    @Test func keepsEverythingOutsideTheMarkers() {
        let readme = "  a\r\n\tb\n<!-- tokencats:start -->x<!-- tokencats:end -->c \n\n\nd"
        let updated = ProfileReadme.upsert(readme, owner: "neko", repo: "neko")
        #expect(updated.hasPrefix("  a\r\n\tb\n"))
        #expect(updated.hasSuffix("c \n\n\nd"))
    }

    @Test func upsertIsStable() {
        let once = ProfileReadme.upsert("hello\n", owner: "neko", repo: "neko")
        #expect(ProfileReadme.upsert(once, owner: "neko", repo: "neko") == once)
    }

    @Test func removeTakesTheBlockAndOneBlankLine() {
        let readme = ProfileReadme.upsert("# Hi\n", owner: "neko", repo: "neko")
        #expect(ProfileReadme.remove(readme) == "# Hi\n")
        #expect(ProfileReadme.remove("no markers\n") == "no markers\n")
        #expect(ProfileReadme.remove("a\n" + block + "\nb") == "a\nb")
    }
}
