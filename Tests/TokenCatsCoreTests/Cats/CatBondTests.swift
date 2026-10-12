import Foundation
import Testing
@testable import TokenCatsCore

private let seoul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}()

private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    seoul.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

struct CatBondTests {
    @Test func levelIsLinearInPointsUpToNinetyNine() {
        #expect(CatBondRules.level(points: 0) == 1)
        #expect(CatBondRules.progress(points: 0) == 0)
        #expect(CatBondRules.level(points: 299) == 1)
        #expect(abs(CatBondRules.progress(points: 299) - 299.0 / 300) < 0.0001)
        #expect(CatBondRules.level(points: 300) == 2)
        #expect(CatBondRules.progress(points: 300) == 0)
        #expect(CatBondRules.level(points: 29_399) == 98)
        #expect(CatBondRules.level(points: 29_400) == 99)
        #expect(CatBondRules.progress(points: 29_400) == 1)
        #expect(CatBondRules.maxPoints == 29_400)
        #expect(CatBondRules.level(points: 1_000_000) == 99)
        #expect(CatBondRules.level(points: -5) == 1)
        // Every level costs the same.
        for level in 1...98 { #expect(CatBondRules.level(points: (level - 1) * CatBondRules.levelCost) == level) }
    }

    @Test func constantsMatchTheSpec() {
        #expect(CatBondRules.maxLevel == 99)
        #expect(CatBondRules.levelCost == 300)
        #expect(CatBondRules.dayPoints == 1_000)
        #expect(CatBondRules.presenceDailyCap == 1_000)
        #expect(CatBondRules.presencePointsPerMinute == 4)
        #expect(CatBondRules.presenceMaxGapMinutes == 5)
        #expect(CatBondRules.petPoints == 10)
        #expect(CatBondRules.treatPoints == 1_000)
    }

    @Test func petAndTreatAddFixedPoints() {
        var book = CatBondBook()
        book.pet("black-1")
        #expect(book.record(of: "black-1").points == 10)
        book.treat("black-1")
        #expect(book.record(of: "black-1").points == 1_010)
        #expect(book.level(of: "black-1") == 4)
        #expect(abs(book.progress(of: "black-1") - 110.0 / 300) < 0.0001)
    }

    @Test func nothingAccruesPastTheLastLevel() {
        var book = CatBondBook()
        for _ in 0..<30 { book.treat("black-1") }
        #expect(book.record(of: "black-1").points == 29_400)
        book.pet("black-1")
        book.treat("black-1")
        book.accruePresence(for: ["black-1"], now: at(12, 9), calendar: seoul)
        book.accruePresence(for: ["black-1"], now: at(12, 9, 1), calendar: seoul)
        #expect(book.record(of: "black-1").points == 29_400)
        #expect(book.level(of: "black-1") == 99)
        #expect(book.progress(of: "black-1") == 1)
    }

    @Test func firstPresenceTickOnlyStartsTheClock() {
        var book = CatBondBook()
        book.accruePresence(for: ["black-1"], now: at(12, 9), calendar: seoul)
        #expect(book.record(of: "black-1").points == 0)
        #expect(book.record(of: "black-1").lastPresenceAt == at(12, 9))
        #expect(book.record(of: "black-1").day == "2026-10-12")
    }

    @Test func presenceCreditsFourPointsAMinute() {
        var book = CatBondBook()
        book.accruePresence(for: ["black-1"], now: at(12, 9), calendar: seoul)
        book.accruePresence(for: ["black-1"], now: at(12, 9, 1), calendar: seoul)
        #expect(book.record(of: "black-1").points == 4)
        book.accruePresence(for: ["black-1"], now: at(12, 9, 3), calendar: seoul)
        #expect(book.record(of: "black-1").points == 12)
        #expect(book.record(of: "black-1").presenceToday == 12)
    }

    @Test func longGapsCreditAtMostFiveMinutes() {
        var book = CatBondBook()
        book.accruePresence(for: ["black-1"], now: at(12, 9), calendar: seoul)
        book.accruePresence(for: ["black-1"], now: at(12, 17), calendar: seoul)   // the Mac slept 8 hours
        #expect(book.record(of: "black-1").points == 20)
    }

    @Test func clockSetBackCreditsNothing() {
        var book = CatBondBook()
        book.accruePresence(for: ["black-1"], now: at(12, 9), calendar: seoul)
        book.accruePresence(for: ["black-1"], now: at(12, 8), calendar: seoul)
        #expect(book.record(of: "black-1").points == 0)
        #expect(book.record(of: "black-1").presenceToday == 0)
        // The clock is re-based so the next forward minute counts again.
        book.accruePresence(for: ["black-1"], now: at(12, 8, 1), calendar: seoul)
        #expect(book.record(of: "black-1").points == 4)
    }

    @Test func presenceStopsAtTheDailyCapAndResetsNextDay() {
        var book = CatBondBook()
        var now = at(12, 9)
        book.accruePresence(for: ["black-1"], now: now, calendar: seoul)
        for _ in 0..<300 {   // five hours of minutes; the cap is reached after 250
            now = now.addingTimeInterval(60)
            book.accruePresence(for: ["black-1"], now: now, calendar: seoul)
        }
        #expect(book.record(of: "black-1").points == 1_000)
        #expect(book.record(of: "black-1").presenceToday == 1_000)
        // Next morning: the day resets, and the long gap still credits only five minutes.
        book.accruePresence(for: ["black-1"], now: at(13, 9), calendar: seoul)
        #expect(book.record(of: "black-1").day == "2026-10-13")
        #expect(book.record(of: "black-1").presenceToday == 20)
        #expect(book.record(of: "black-1").points == 1_020)
    }

    @Test func catsNotListedAreUntouched() {
        var book = CatBondBook()
        book.accruePresence(for: ["black-1", "white-1"], now: at(12, 9), calendar: seoul)
        book.accruePresence(for: ["black-1"], now: at(12, 9, 2), calendar: seoul)
        #expect(book.record(of: "black-1").points == 8)
        #expect(book.record(of: "white-1").points == 0)
        #expect(book.record(of: "white-1").lastPresenceAt == at(12, 9))
        // Back in the room an hour later: one capped gap, not the hour.
        book.accruePresence(for: ["black-1", "white-1"], now: at(12, 10), calendar: seoul)
        #expect(book.record(of: "white-1").points == 20)
    }

    @Test func unknownCatIsLevelOneUntilTouched() {
        var book = CatBondBook()
        #expect(book.level(of: "ghost-1") == 1)
        #expect(book.progress(of: "ghost-1") == 0)
        #expect(book.bonds.isEmpty)
        book.pet("ghost-1")
        #expect(book.bonds.keys.contains("ghost-1"))
    }

    @Test func forgetRemovesTheCat() {
        var book = CatBondBook()
        book.treat("black-1")
        book.forget("black-1")
        #expect(book.bonds.isEmpty)
        #expect(book.level(of: "black-1") == 1)
        book.forget("never-here")   // no crash, no entry
        #expect(book.bonds.isEmpty)
    }

    @Test func roundTripsThroughJSON() throws {
        var book = CatBondBook()
        book.treat("black-1")
        book.accruePresence(for: ["black-1"], now: at(12, 9), calendar: seoul)
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(CatBondBook.self, from: data)
        #expect(decoded == book)
        let empty = try JSONDecoder().decode(CatBondBook.self, from: Data(#"{"bonds":{}}"#.utf8))
        #expect(empty == CatBondBook())
    }
}
