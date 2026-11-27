import XCTest
@testable import DaybookKit

final class NaturalLanguageParserTests: XCTestCase {
    let parser = NaturalLanguageParser(calendar: T.cal, now: T.now)

    func testSpecExample() {
        let p = parser.parse("Lunch with Ana tomorrow 1pm at Origo #personal")
        XCTAssertEqual(p.title, "Lunch with Ana")
        XCTAssertEqual(p.date, T.date(2026, 11, 28))
        XCTAssertEqual(p.startMinute, 13 * 60)
        XCTAssertEqual(p.location, "Origo")
        XCTAssertEqual(p.calendarTag, "personal")
        let r = parser.resolve(p, selectedDay: T.now)
        XCTAssertEqual(r.start, T.date(2026, 11, 28, 13))
        XCTAssertEqual(r.end, T.date(2026, 11, 28, 14))
        XCTAssertFalse(r.isAllDay)
    }

    func testWeekdayIsNextOccurrence() {
        // Today is Friday, so "Friday" means next week's Friday.
        let p = parser.parse("Dinner with Ana Friday 8pm #family")
        XCTAssertEqual(p.title, "Dinner with Ana")
        XCTAssertEqual(p.date, T.date(2026, 12, 4))
        XCTAssertEqual(p.startMinute, 20 * 60)
        XCTAssertEqual(p.calendarTag, "family")

        XCTAssertEqual(parser.parse("Standup mon").date, T.date(2026, 11, 30))
        XCTAssertEqual(parser.parse("Call on Sunday").date, T.date(2026, 11, 29))
        XCTAssertEqual(parser.parse("Call on Sunday").title, "Call")
        XCTAssertEqual(parser.parse("Review next tuesday").date, T.date(2026, 12, 8))
    }

    func testTimeRange() {
        let p = parser.parse("Sprint planning Monday 10-11:30 #work")
        XCTAssertEqual(p.title, "Sprint planning")
        XCTAssertEqual(p.startMinute, 10 * 60)
        XCTAssertEqual(p.endMinute, 11 * 60 + 30)

        let q = parser.parse("Workshop 9:30–11")
        XCTAssertEqual(q.startMinute, 9 * 60 + 30)
        XCTAssertEqual(q.endMinute, 11 * 60)

        let r = parser.parse("Call 2-4pm")
        XCTAssertEqual(r.startMinute, 14 * 60)
        XCTAssertEqual(r.endMinute, 16 * 60)
    }

    func testDuration() {
        let p = parser.parse("Gym tomorrow 7am for 90 min #fitness")
        XCTAssertEqual(p.title, "Gym")
        XCTAssertEqual(p.startMinute, 7 * 60)
        XCTAssertEqual(p.durationMinutes, 90)
        XCTAssertEqual(p.endMinute, 8 * 60 + 30)
        XCTAssertEqual(parser.parse("Focus 2h").durationMinutes, 120)
        XCTAssertEqual(parser.parse("Walk 45m").durationMinutes, 45)
    }

    func testSingleTimes() {
        XCTAssertEqual(parser.parse("Dinner at 6").startMinute, 18 * 60)
        XCTAssertEqual(parser.parse("Dinner at 6").title, "Dinner")
        XCTAssertEqual(parser.parse("Train at 9").startMinute, 9 * 60)
        XCTAssertEqual(parser.parse("Run 7 am").startMinute, 7 * 60)
        XCTAssertEqual(parser.parse("Call 18:30").startMinute, 18 * 60 + 30)
        XCTAssertEqual(parser.parse("Lunch 12pm").startMinute, 12 * 60)
        XCTAssertEqual(parser.parse("Wake 12am").startMinute, 0)
    }

    func testRelativeDates() {
        XCTAssertEqual(parser.parse("Pay rent today").date, T.date(2026, 11, 27))
        let tonight = parser.parse("Movie tonight")
        XCTAssertEqual(tonight.date, T.date(2026, 11, 27))
        XCTAssertEqual(tonight.startMinute, 20 * 60)
        XCTAssertEqual(tonight.title, "Movie")
        XCTAssertEqual(parser.parse("Movie tonight 21:30").startMinute, 21 * 60 + 30)
        XCTAssertEqual(parser.parse("Plan next week").date, T.date(2026, 11, 30))
    }

    func testMonthDates() {
        XCTAssertEqual(parser.parse("Party 3 dec").date, T.date(2026, 12, 3))
        XCTAssertEqual(parser.parse("Party dec 3").date, T.date(2026, 12, 3))
        XCTAssertEqual(parser.parse("Party 3rd December").date, T.date(2026, 12, 3))
        XCTAssertEqual(parser.parse("Pay rent on 1 dec").title, "Pay rent")
        // Already passed this year, so next year.
        XCTAssertEqual(parser.parse("Birthday 5 may").date, T.date(2027, 5, 5))
        // Invalid day is ignored.
        XCTAssertNil(parser.parse("Thing 31 feb").date)
    }

    func testAllDay() {
        let p = parser.parse("Ski weekend 12 dec all day")
        XCTAssertTrue(p.isAllDay)
        XCTAssertEqual(p.title, "Ski weekend")
        let r = parser.resolve(p, selectedDay: T.now)
        XCTAssertTrue(r.isAllDay)
        XCTAssertEqual(r.start, T.date(2026, 12, 12))
        XCTAssertEqual(r.end, T.date(2026, 12, 13))
    }

    func testLocationNeedsCapital() {
        XCTAssertNil(parser.parse("Meet at home").location)
        XCTAssertEqual(parser.parse("Coffee at Cafe Origo").location, "Cafe Origo")
        XCTAssertEqual(parser.parse("Coffee at Cafe Origo").title, "Coffee")
        XCTAssertEqual(parser.parse("Drinks at Origo tomorrow").location, "Origo")
    }

    func testNothingRecognisedUsesDefaults() {
        let p = parser.parse("Read a book")
        XCTAssertEqual(p.title, "Read a book")
        XCTAssertFalse(p.recognisedAnything)
        let r = parser.resolve(p, selectedDay: T.date(2026, 12, 2))
        XCTAssertEqual(r.start, T.date(2026, 12, 2, 9))
        XCTAssertEqual(r.end, T.date(2026, 12, 2, 10))
    }

    func testTokensPointIntoOriginalText() {
        let text = "Lunch tomorrow 1pm #personal"
        let p = parser.parse(text)
        let ns = text as NSString
        let texts = p.tokens.map { ns.substring(with: $0.range) }
        XCTAssertEqual(texts, ["tomorrow", "1pm", "#personal"])
        XCTAssertEqual(p.tokens.map(\.kind), [.date, .time, .calendar])
    }

    func testWordsThatLookLikeDaysAreKept() {
        XCTAssertEqual(parser.parse("Monthly review").title, "Monthly review")
        XCTAssertNil(parser.parse("Monthly review").date)
    }
}
