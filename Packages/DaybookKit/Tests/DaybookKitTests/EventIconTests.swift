import XCTest
@testable import DaybookKit

final class EventIconTests: XCTestCase {
    func testCommonTitles() {
        XCTAssertEqual(EventIcon.symbol(for: "Gym"), "dumbbell.fill")
        XCTAssertEqual(EventIcon.symbol(for: "Morning run"), "figure.run")
        XCTAssertEqual(EventIcon.symbol(for: "Ana's birthday"), "gift.fill")
        XCTAssertEqual(EventIcon.symbol(for: "Flight to London"), "airplane.departure")
        XCTAssertEqual(EventIcon.symbol(for: "Dinner with Ioana"), "fork.knife")
        XCTAssertEqual(EventIcon.symbol(for: "Tennis"), "tennis.racket")
        XCTAssertEqual(EventIcon.symbol(for: "Book club"), "book.fill")
    }

    func testCaseAndPluralsAndPunctuation() {
        XCTAssertEqual(EventIcon.symbol(for: "FLIGHTS!"), "airplane.departure")
        XCTAssertEqual(EventIcon.symbol(for: "team-meeting"), "person.2.fill")
    }

    func testShortKeywordsNeedWholeWords() {
        // "run" must not match inside "brunch"; brunch is a meal.
        XCTAssertEqual(EventIcon.symbol(for: "Sunday brunch"), "fork.knife")
        // "dr" must not match "drinks".
        XCTAssertEqual(EventIcon.symbol(for: "Drinks"), "wineglass.fill")
        XCTAssertEqual(EventIcon.symbol(for: "Dr Popescu"), "cross.case.fill")
    }

    func testNoMatch() {
        XCTAssertNil(EventIcon.symbol(for: "Quarterly planning thing"))
        XCTAssertNil(EventIcon.symbol(for: ""))
        XCTAssertNil(EventIcon.symbol(for: "   "))
    }
}
