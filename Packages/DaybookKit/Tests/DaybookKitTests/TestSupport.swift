import Foundation
@testable import DaybookKit

enum T {
    static var cal: Calendar = {
        var s = DaybookSettings()
        s.weekStartsOnMonday = true
        return s.calendar(timeZone: TimeZone(identifier: "Europe/Bucharest")!)
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Friday 27 November 2026, 08:54.
    static let now = date(2026, 11, 27, 8, 54)

    static func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false, title: String? = nil,
                      cal calID: String = "work", location: String? = nil) -> CalEvent {
        CalEvent(id: id, title: title ?? id, calendarID: calID, start: start, end: end, isAllDay: allDay, location: location)
    }

    static func minutes(_ d: Date) -> Int { DateMath.minutesSinceStartOfDay(d, calendar: cal) }
}
