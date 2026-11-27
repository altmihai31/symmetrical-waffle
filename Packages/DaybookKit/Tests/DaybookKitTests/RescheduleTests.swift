import XCTest
@testable import DaybookKit

final class RescheduleTests: XCTestCase {
    let cal = T.cal

    func testMoveKeepsTimeAndLength() {
        let r = Reschedule.move(start: T.date(2026, 12, 3, 19), end: T.date(2026, 12, 3, 21),
                                toDay: T.date(2026, 11, 30, 15, 12), calendar: cal)
        XCTAssertEqual(r.start, T.date(2026, 11, 30, 19))
        XCTAssertEqual(r.end, T.date(2026, 11, 30, 21))
    }

    func testMoveAcrossDSTKeepsWallClock() {
        // Romania leaves summer time on 25 October 2026.
        let r = Reschedule.move(start: T.date(2026, 10, 24, 9), end: T.date(2026, 10, 24, 10),
                                toDay: T.date(2026, 10, 26), calendar: cal)
        XCTAssertEqual(T.minutes(r.start), 9 * 60)
        XCTAssertEqual(T.minutes(r.end), 10 * 60)
    }

    func testMoveMultiDayKeepsSpan() {
        let r = Reschedule.move(start: T.date(2026, 12, 1), end: T.date(2026, 12, 4),
                                toDay: T.date(2026, 12, 10), calendar: cal)
        XCTAssertEqual(r.start, T.date(2026, 12, 10))
        XCTAssertEqual(r.end, T.date(2026, 12, 13))
    }

    func testMoveTaskDue() {
        XCTAssertEqual(Reschedule.move(due: nil, toDay: T.date(2026, 12, 2, 13), calendar: cal), T.date(2026, 12, 2))
        XCTAssertEqual(Reschedule.move(due: T.date(2026, 11, 28, 18), toDay: T.date(2026, 12, 2), calendar: cal),
                       T.date(2026, 12, 2, 18))
    }

    func testPostpone() {
        // No due date, or overdue: tomorrow.
        XCTAssertEqual(Reschedule.postponed(due: nil, now: T.now, calendar: cal), T.date(2026, 11, 28))
        XCTAssertEqual(Reschedule.postponed(due: T.date(2026, 11, 20, 9), now: T.now, calendar: cal),
                       T.date(2026, 11, 28, 9))
        // Due today with a time: tomorrow, same time.
        XCTAssertEqual(Reschedule.postponed(due: T.date(2026, 11, 27, 17), now: T.now, calendar: cal),
                       T.date(2026, 11, 28, 17))
        // Due later: one day after the due date.
        XCTAssertEqual(Reschedule.postponed(due: T.date(2026, 12, 5), now: T.now, calendar: cal), T.date(2026, 12, 6))
    }
}
