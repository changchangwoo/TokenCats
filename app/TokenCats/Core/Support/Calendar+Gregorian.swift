import Foundation

extension Calendar {
    /// The same time zone and week layout on the Gregorian calendar. Day keys ("2026-10-11"), month labels and the
    /// card's date are Gregorian whatever calendar the Mac is set to: a Hebrew year has 13 months, a Japanese one
    /// counts years by era, and either would break keys saved before the setting changed.
    var gregorian: Calendar {
        guard identifier != .gregorian else { return self }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        return calendar
    }
}
