import Foundation
import Testing
@testable import TokenCatsCore

struct CatBondServiceTests {
    @Test func startsEmptyAndSavesChanges() throws {
        let url = try makeTempDirectory().appendingPathComponent("bonds.json")
        let service = CatBondService(file: JSONFile(url: url))
        #expect(service.book == CatBondBook())
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let book = service.pet("black-1")
        #expect(book.level(of: "black-1") == 1)
        #expect(book.record(of: "black-1").points == 10)
        #expect(JSONFile<CatBondBook>(url: url).load() == book)
        let reopened = CatBondService(file: JSONFile(url: url))
        #expect(reopened.book == book)
    }

    @Test func nothingChangedNothingWritten() throws {
        let url = try makeTempDirectory().appendingPathComponent("bonds.json")
        let service = CatBondService(file: JSONFile(url: url))
        // Forgetting a cat that was never there changes nothing.
        service.forget("ghost-1")
        #expect(!FileManager.default.fileExists(atPath: url.path))
        // At the last level, a pet changes nothing either.
        for _ in 0..<30 { service.treat("black-1") }
        let written = try Data(contentsOf: url)
        service.pet("black-1")
        #expect(try Data(contentsOf: url) == written)
    }

    @Test func failedSaveKeepsThePreviousBook() throws {
        // bonds.json's parent is a regular file, so saving it fails.
        let blocker = try makeTempDirectory().appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let service = CatBondService(file: JSONFile(url: blocker.appendingPathComponent("bonds.json")))
        let book = service.treat("black-1")
        #expect(book == CatBondBook())
        #expect(service.book == CatBondBook())
    }

    @Test func presenceGoesThroughTheService() throws {
        let url = try makeTempDirectory().appendingPathComponent("bonds.json")
        let service = CatBondService(file: JSONFile(url: url))
        let start = Date()
        service.accruePresence(for: ["black-1"], now: start)
        let book = service.accruePresence(for: ["black-1"], now: start.addingTimeInterval(120))
        #expect(book.record(of: "black-1").points == 8)
        #expect(JSONFile<CatBondBook>(url: url).load() == book)
    }
}
