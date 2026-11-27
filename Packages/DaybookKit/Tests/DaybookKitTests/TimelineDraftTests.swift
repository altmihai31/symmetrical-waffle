import XCTest
@testable import DaybookKit

final class TimelineDraftTests: XCTestCase {
    func testSnap() {
        XCTAssertEqual(TimelineDraft.snap(607), 600)
        XCTAssertEqual(TimelineDraft.snap(608), 615)
        XCTAssertEqual(TimelineDraft.snap(-20), 0)
        XCTAssertEqual(TimelineDraft.snap(1500), 1440)
        XCTAssertEqual(TimelineDraft.floorSnap(620), 615)
        XCTAssertEqual(TimelineDraft.floorSnap(1439), 1425)
    }

    func testPressWithoutDragUsesDefaultLength() {
        let r = TimelineDraft.range(anchor: 600, current: 600, defaultLength: 60, moved: false)
        XCTAssertEqual(r.start, 600); XCTAssertEqual(r.end, 660)
        // Near midnight the draft is clipped to the day.
        let late = TimelineDraft.range(anchor: 1410, current: 1410, defaultLength: 60, moved: false)
        XCTAssertEqual(late.end, 1440); XCTAssertEqual(late.start, 1410)
    }

    func testDragDownSetsEnd() {
        let r = TimelineDraft.range(anchor: 600, current: 692, moved: true)
        XCTAssertEqual(r.start, 600); XCTAssertEqual(r.end, 690)
    }

    func testDragBarelyKeepsMinimumLength() {
        let r = TimelineDraft.range(anchor: 600, current: 603, moved: true)
        XCTAssertEqual(r.start, 600); XCTAssertEqual(r.end, 615)
    }

    func testDragUpFlips() {
        let r = TimelineDraft.range(anchor: 600, current: 530, moved: true)
        XCTAssertEqual(r.start, 525); XCTAssertEqual(r.end, 600)
    }

    func testDate() {
        let d = TimelineDraft.date(minute: 615, on: T.now, calendar: T.cal)
        XCTAssertEqual(d, T.date(2026, 11, 27, 10, 15))
    }
}

final class DayCompletionTests: XCTestCase {
    private func task(_ id: String, _ due: Date?, done: Bool = false) -> TaskItem {
        TaskItem(id: id, title: id, listID: "l", due: due, isCompleted: done)
    }

    func testLastOpenTaskCompletesDay() {
        let a = task("a", T.date(2026, 11, 27, 9), done: true)
        let b = task("b", T.date(2026, 11, 27, 16))
        let other = task("c", T.date(2026, 11, 28))
        XCTAssertTrue(DayCompletion.completesDay(b, among: [a, b, other], calendar: T.cal))
    }

    func testNotLastWhenAnotherIsOpen() {
        let a = task("a", T.date(2026, 11, 27, 9))
        let b = task("b", T.date(2026, 11, 27, 16))
        XCTAssertFalse(DayCompletion.completesDay(b, among: [a, b], calendar: T.cal))
    }

    func testDoneOrUndatedNeverCompletes() {
        XCTAssertFalse(DayCompletion.completesDay(task("x", nil), among: [], calendar: T.cal))
        let done = task("d", T.now, done: true)
        XCTAssertFalse(DayCompletion.completesDay(done, among: [done], calendar: T.cal))
    }

    func testAllCaughtUp() {
        let past = task("p", T.date(2026, 11, 26), done: true)
        let future = task("f", T.date(2026, 11, 30))
        XCTAssertTrue(DayCompletion.allCaughtUp([past, future], now: T.now, calendar: T.cal))
        let open = task("o", T.date(2026, 11, 27, 18))
        XCTAssertFalse(DayCompletion.allCaughtUp([past, open], now: T.now, calendar: T.cal))
        XCTAssertFalse(DayCompletion.allCaughtUp([], now: T.now, calendar: T.cal))
    }
}
