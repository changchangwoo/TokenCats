import Foundation
import Testing
@testable import TokenCatsCore

struct DataFilesTests {
    /// The one place a data file name is spelled: every model asks here instead of concatenating strings.
    @Test func namesEveryFileOnce() throws {
        let files = DataFiles(directory: URL(fileURLWithPath: "/tmp/x"))
        #expect(files.cats.url.lastPathComponent == "cats.json")
        #expect(files.churu.url.lastPathComponent == "churu.json")
        #expect(files.inventory.url.lastPathComponent == "inventory.json")
        #expect(files.uiDisplay.url.lastPathComponent == "ui-display.json")
        #expect(files.profileSync.url.lastPathComponent == "profile-sync.json")
        #expect(files.dailyHistory.url.lastPathComponent == "daily-history.json")
        #expect(files.results.url.lastPathComponent == "results.json")
        #expect(files.sessions.url.lastPathComponent == "sessions.json")
    }

    /// A backup carries exactly the user's data, and the list lives with the file names.
    @Test func backupCarriesTheUserDataFiles() {
        #expect(Backup.files == DataFiles.userDataNames)
        #expect(Set(DataFiles.userDataNames) == ["cats.json", "churu.json", "inventory.json", "ui-display.json", "profile-sync.json"])
    }

    @Test func liveFilesSitInTheSupportDirectory() {
        #expect(DataFiles.live.directory == AppPaths.supportDirectory)
    }
}
