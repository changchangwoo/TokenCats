import Foundation
import Testing
@testable import TokenCatsCore

struct AppPathsTests {
    /// Snapshots and tests point the app at a frozen copy of its data with `NC_SUPPORT_DIR` (Debug builds only).
    @Test func supportDirectoryFollowsTheEnvironmentOverride() {
        let overridden = AppPaths.supportDirectory(environment: ["NC_SUPPORT_DIR": "/tmp/tokencats-frozen"])
        #expect(overridden.path == "/tmp/tokencats-frozen")
    }

    @Test func supportDirectoryDefaultsToApplicationSupport() {
        #expect(AppPaths.supportDirectory(environment: [:]).path.hasSuffix("/Library/Application Support/TokenCats"))
        #expect(AppPaths.supportDirectory(environment: ["NC_SUPPORT_DIR": ""]).path.hasSuffix("/TokenCats"))
    }
}
