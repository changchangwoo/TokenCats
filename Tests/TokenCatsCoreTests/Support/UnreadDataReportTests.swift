import Foundation
import Testing
@testable import TokenCatsCore

struct UnreadDataReportTests {
    @Test func listsFilesMovedAsideSinceTheLastNotice() throws {
        let dir = try makeTempDirectory()
        for name in ["cats.corrupt-1000.json", "churu.corrupt-3000.json", "cats.json", "notes.txt", "churu.corrupt-x.json"] {
            FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data("{}".utf8))
        }
        #expect(UnreadDataReport.files(in: dir, after: Date(timeIntervalSince1970: 0)) == ["cats.json", "churu.json"])
        #expect(UnreadDataReport.files(in: dir, after: Date(timeIntervalSince1970: 2000)) == ["churu.json"])
        #expect(UnreadDataReport.files(in: dir, after: Date(timeIntervalSince1970: 3000)).isEmpty)
        #expect(UnreadDataReport.files(in: dir.appendingPathComponent("missing"), after: .distantPast).isEmpty)
    }

    /// The name JSONFile gives a file it could not read is the one the report looks for.
    @Test func matchesWhatJSONFileLeavesBehind() throws {
        let dir = try makeTempDirectory()
        let file = JSONFile<CatHousehold>(url: dir.appendingPathComponent("cats.json"))
        try Data("not json".utf8).write(to: file.url)
        #expect(file.load(now: Date(timeIntervalSince1970: 5000)) == nil)
        #expect(UnreadDataReport.files(in: dir, after: Date(timeIntervalSince1970: 4000)) == ["cats.json"])
    }
}
