import XCTest
@testable import DaybookKit

final class CalendarLayoutTests: XCTestCase {
    let cal = T.cal

    func testMonthGridStartsMonday() {
        let grid = MonthGrid(containing: T.date(2026, 11, 15), calendar: cal)
        XCTAssertEqual(grid.weeks.count, 6)
        XCTAssertEqual(grid.weeks.first?.first, T.date(2026, 10, 26))
        XCTAssertEqual(grid.weeks.last?.last, T.date(2026, 12, 6))
        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
        XCTAssertFalse(grid.isInMonth(T.date(2026, 10, 31), calendar: cal))
        XCTAssertTrue(grid.isInMonth(T.date(2026, 11, 1), calendar: cal))
    }

    func testMonthGridFiveRows() {
        // February 2027 starts on a Monday and has 28 days.
        let grid = MonthGrid(containing: T.date(2027, 2, 10), calendar: cal)
        XCTAssertEqual(grid.weeks.count, 4)
        let dec = MonthGrid(containing: T.date(2026, 12, 10), calendar: cal)
        XCTAssertEqual(dec.weeks.count, 5)
        XCTAssertEqual(dec.weeks.first?.first, T.date(2026, 11, 30))
    }

    func testSundayStart() {
        var s = DaybookSettings()
        s.weekStartsOnMonday = false
        let sunCal = s.calendar(timeZone: cal.timeZone)
        let grid = MonthGrid(containing: T.date(2026, 11, 15), calendar: sunCal)
        XCTAssertEqual(grid.weeks.first?.first, sunCal.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        XCTAssertEqual(DateMath.weekdaySymbols(calendar: sunCal).first, "Sun")
        XCTAssertEqual(DateMath.weekdaySymbols(calendar: cal).first, "Mon")
    }

    func testEventDays() {
        let allDayExclusive = T.event("a", T.date(2026, 11, 12), T.date(2026, 11, 16), allDay: true)
        XCTAssertEqual(allDayExclusive.days(in: cal).count, 4)
        let allDayInclusive = T.event("b", T.date(2026, 11, 12), T.date(2026, 11, 12, 23, 59), allDay: true)
        XCTAssertEqual(allDayInclusive.days(in: cal).count, 1)
        XCTAssertFalse(allDayInclusive.isMultiDay(in: cal))
        let overnight = T.event("c", T.date(2026, 11, 12, 22), T.date(2026, 11, 13, 2))
        XCTAssertTrue(overnight.isMultiDay(in: cal))
        let toMidnight = T.event("d", T.date(2026, 11, 12, 22), T.date(2026, 11, 13))
        XCTAssertFalse(toMidnight.isMultiDay(in: cal))
        XCTAssertTrue(allDayExclusive.occurs(on: T.date(2026, 11, 15, 12), in: cal))
        XCTAssertFalse(allDayExclusive.occurs(on: T.date(2026, 11, 16), in: cal))
    }

    func testBarLanes() {
        let week = DateMath.week(containing: T.date(2026, 11, 12), calendar: cal) // Mon 9 – Sun 15
        let berlin = T.event("berlin", T.date(2026, 11, 12), T.date(2026, 11, 16), allDay: true)
        let conf = T.event("conf", T.date(2026, 11, 13), T.date(2026, 11, 15), allDay: true)
        let later = T.event("later", T.date(2026, 11, 9), T.date(2026, 11, 11), allDay: true)
        let single = T.event("single", T.date(2026, 11, 10), T.date(2026, 11, 11), allDay: true)
        let segs = MonthLayout.barSegments(week: week, events: [berlin, conf, later, single], calendar: cal)
        XCTAssertEqual(segs.count, 3)
        let byID = Dictionary(uniqueKeysWithValues: segs.map { ($0.eventID, $0) })
        XCTAssertEqual(byID["later"]?.startColumn, 0)
        XCTAssertEqual(byID["later"]?.endColumn, 1)
        XCTAssertEqual(byID["later"]?.lane, 0)
        XCTAssertEqual(byID["berlin"]?.startColumn, 3)
        XCTAssertEqual(byID["berlin"]?.endColumn, 6)
        XCTAssertEqual(byID["berlin"]?.lane, 0)
        XCTAssertEqual(byID["conf"]?.lane, 1)
        XCTAssertEqual(MonthLayout.reservedLanes(for: segs), [1, 1, 0, 1, 2, 2, 1])
    }

    func testBarContinuesAcrossWeeks() {
        let trip = T.event("trip", T.date(2026, 11, 20), T.date(2026, 11, 25), allDay: true)
        let week1 = DateMath.week(containing: T.date(2026, 11, 20), calendar: cal)
        let week2 = DateMath.week(containing: T.date(2026, 11, 24), calendar: cal)
        let s1 = MonthLayout.barSegments(week: week1, events: [trip], calendar: cal)[0]
        let s2 = MonthLayout.barSegments(week: week2, events: [trip], calendar: cal)[0]
        XCTAssertEqual(s1.startColumn, 4); XCTAssertEqual(s1.endColumn, 6)
        XCTAssertTrue(s1.continuesAfter); XCTAssertFalse(s1.continuesBefore)
        XCTAssertEqual(s2.startColumn, 0); XCTAssertEqual(s2.endColumn, 1)
        XCTAssertTrue(s2.continuesBefore); XCTAssertFalse(s2.continuesAfter)
    }

    func testDayOrdering() {
        let day = T.date(2026, 11, 27)
        let events = [
            T.event("late", T.date(2026, 11, 27, 18), T.date(2026, 11, 27, 19)),
            T.event("early", T.date(2026, 11, 27, 8), T.date(2026, 11, 27, 9)),
            T.event("holiday", day, T.date(2026, 11, 28), allDay: true),
            T.event("trip", T.date(2026, 11, 26), T.date(2026, 11, 29), allDay: true)
        ]
        let tasks = [
            TaskItem(id: "t1", title: "Buy milk", listID: "p", due: day),
            TaskItem(id: "t2", title: "Call", listID: "p", due: T.date(2026, 11, 27, 10), dueHasTime: true),
            TaskItem(id: "t3", title: "Done one", listID: "p", due: day, isCompleted: true)
        ]
        let items = DayContent.items(on: day, events: events, tasks: tasks, includeTasks: true, calendar: cal)
        XCTAssertEqual(items.map(\.title), ["holiday", "early", "late", "Call", "Buy milk", "Done one"])
        let noTasks = DayContent.items(on: day, events: events, tasks: tasks, includeTasks: false, calendar: cal)
        XCTAssertEqual(noTasks.count, 3)
        let withBars = DayContent.items(on: day, events: events, tasks: [], includeTasks: false,
                                        includeMultiDay: true, calendar: cal)
        XCTAssertEqual(withBars.count, 4)
    }

    func testTimelineOverlap() {
        let day = T.date(2026, 11, 27)
        let events = [
            T.event("a", T.date(2026, 11, 27, 9), T.date(2026, 11, 27, 10)),
            T.event("b", T.date(2026, 11, 27, 9, 30), T.date(2026, 11, 27, 11)),
            T.event("c", T.date(2026, 11, 27, 10), T.date(2026, 11, 27, 10, 30)),
            T.event("d", T.date(2026, 11, 27, 12), T.date(2026, 11, 27, 12, 5)),
            T.event("night", T.date(2026, 11, 26, 23), T.date(2026, 11, 27, 1))
        ]
        let slots = Dictionary(uniqueKeysWithValues: TimelineLayout.slots(for: day, events: events, calendar: cal).map { ($0.eventID, $0) })
        XCTAssertEqual(slots["a"]?.column, 0)
        XCTAssertEqual(slots["b"]?.column, 1)
        XCTAssertEqual(slots["c"]?.column, 0)
        XCTAssertEqual(slots["a"]?.columnCount, 2)
        XCTAssertEqual(slots["c"]?.columnCount, 2)
        XCTAssertEqual(slots["d"]?.columnCount, 1)
        XCTAssertEqual(slots["d"]?.endMinute, 12 * 60 + TimelineLayout.minimumMinutes)
        XCTAssertEqual(slots["night"]?.startMinute, 0)
        XCTAssertEqual(slots["night"]?.endMinute, 60)
    }

    func testTaskGrouping() {
        let tasks = [
            TaskItem(id: "1", title: "Old", listID: "p", due: T.date(2026, 11, 25)),
            TaskItem(id: "2", title: "Earlier today", listID: "p", due: T.date(2026, 11, 27, 8), dueHasTime: true),
            TaskItem(id: "3", title: "Today", listID: "p", due: T.date(2026, 11, 27)),
            TaskItem(id: "4", title: "Later today", listID: "p", due: T.date(2026, 11, 27, 17), dueHasTime: true),
            TaskItem(id: "5", title: "Soon", listID: "p", due: T.date(2026, 12, 1)),
            TaskItem(id: "6", title: "Someday", listID: "p"),
            TaskItem(id: "7", title: "Finished", listID: "p", due: T.date(2026, 11, 20), isCompleted: true,
                     completionDate: T.date(2026, 11, 21))
        ]
        let groups = TaskGrouping.group(tasks, now: T.now, calendar: cal)
        XCTAssertEqual(groups.map { $0.group }, [.overdue, .today, .upcoming, .noDate, .done])
        XCTAssertEqual(groups[0].tasks.map(\.title), ["Old", "Earlier today"])
        XCTAssertEqual(groups[1].tasks.map(\.title), ["Today", "Later today"])
        XCTAssertEqual(groups[2].tasks.map(\.title), ["Soon"])
        XCTAssertEqual(groups[4].tasks.map(\.title), ["Finished"])
    }

    func testAgendaHeaders() {
        let events = [
            T.event("a", T.date(2026, 11, 27, 9), T.date(2026, 11, 27, 10)),
            T.event("b", T.date(2026, 11, 28, 9), T.date(2026, 11, 28, 10)),
            T.event("c", T.date(2026, 11, 30, 9), T.date(2026, 11, 30, 10))
        ]
        let sections = Agenda.sections(from: T.now, days: 7, events: events, tasks: [], includeTasks: true,
                                       now: T.now, calendar: cal)
        XCTAssertEqual(sections.map(\.title), ["Today", "Tomorrow", "Monday 30 Nov"])
    }

    func testSearch() {
        let cals = [CalendarInfo(id: "fam", title: "Family", colorHex: "#ff9500", account: .iCloud)]
        let events = [
            T.event("Dinner", T.date(2026, 11, 28, 20), T.date(2026, 11, 28, 21), cal: "fam"),
            T.event("Standup", T.date(2026, 11, 30, 9), T.date(2026, 11, 30, 9, 15), location: "Brașov office")
        ]
        let tasks = [TaskItem(id: "x", title: "Buy dinner wine", listID: "p")]
        XCTAssertEqual(Search.results("dinner", events: events, tasks: tasks, calendars: cals, now: T.now, calendar: cal)
            .flatMap(\.items).count, 2)
        XCTAssertEqual(Search.results("family", events: events, tasks: tasks, calendars: cals, now: T.now, calendar: cal)
            .flatMap(\.items).map(\.title), ["Dinner"])
        XCTAssertEqual(Search.results("brasov", events: events, tasks: tasks, calendars: cals, now: T.now, calendar: cal)
            .flatMap(\.items).map(\.title), ["Standup"])
        XCTAssertTrue(Search.results("  ", events: events, tasks: tasks, calendars: cals, now: T.now, calendar: cal).isEmpty)
    }

    func testTimeText() {
        XCTAssertEqual(DateText.time(minutes: 13 * 60 + 5, use24h: true), "13:05")
        XCTAssertEqual(DateText.time(minutes: 13 * 60 + 5, use24h: false), "1:05pm")
        XCTAssertEqual(DateText.time(minutes: 0, use24h: false), "12am")
        XCTAssertEqual(DateText.duration(minutes: 90), "1h 30m")
        let trip = T.event("trip", T.date(2026, 11, 20), T.date(2026, 11, 23), allDay: true)
        XCTAssertEqual(DateText.eventTimeRange(trip, use24h: true, calendar: cal), "Fri 20 Nov – Sun 22 Nov")
        XCTAssertEqual(DateText.monthName(T.now, calendar: cal), "November")
    }

    func testNextRoundHourAndStrip() {
        XCTAssertEqual(DateMath.nextRoundHour(on: T.date(2026, 12, 1), now: T.now, calendar: cal), T.date(2026, 12, 1, 9))
        let strip = DateMath.monthStrip(around: T.now, before: 2, after: 2, calendar: cal)
        XCTAssertEqual(strip.map { DateText.monthName($0, calendar: cal, short: true) }, ["Sep", "Oct", "Nov", "Dec", "Jan"])
    }

    func testWeekRowsText() {
        let start = T.date(2026, 11, 27)
        XCTAssertEqual(DateText.weekRangeTitle(start, calendar: cal), "27 Nov - 3 Dec")
        XCTAssertEqual(DateText.weekRangeTitle(T.date(2026, 11, 2), calendar: cal), "2 - 8 Nov")
        XCTAssertEqual(DateText.weekStripLabel(start, calendar: cal).months, "Nov-Dec")
        XCTAssertEqual(DateText.weekStripLabel(start, calendar: cal).days, "27-3")
        XCTAssertEqual(DateText.weekStripLabel(T.date(2026, 11, 13), calendar: cal).months, "Nov")
        XCTAssertEqual(DateText.fullDay(T.date(2026, 11, 18), calendar: cal), "Wednesday, 18 November")
        XCTAssertEqual(DateText.shortDayComma(T.date(2026, 11, 18), calendar: cal), "Wed, 18 Nov")
        let days = DateMath.days(from: T.date(2026, 11, 27, 15), count: 7, calendar: cal)
        XCTAssertEqual(days.first, start)
        XCTAssertEqual(days.last, T.date(2026, 12, 3))
    }

    func testAlertClosest() {
        XCTAssertEqual(AlertOption.closest(toMinutesBefore: nil), .none)
        XCTAssertEqual(AlertOption.closest(toMinutesBefore: 10), .min5)
        XCTAssertEqual(AlertOption.closest(toMinutesBefore: 50), .hour1)
    }
}
