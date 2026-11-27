import XCTest
@testable import DaybookKit

final class AccountClassifierTests: XCTestCase {
    func testClassify() {
        XCTAssertEqual(AccountClassifier.classify(kind: .calDAV, sourceTitle: "iCloud"), .iCloud)
        XCTAssertEqual(AccountClassifier.classify(kind: .calDAV, sourceTitle: "Gmail"), .google)
        XCTAssertEqual(AccountClassifier.classify(kind: .calDAV, sourceTitle: "me@gmail.com"), .google)
        XCTAssertEqual(AccountClassifier.classify(kind: .exchange, sourceTitle: "Work"), .outlook)
        XCTAssertEqual(AccountClassifier.classify(kind: .calDAV, sourceTitle: "Outlook.com"), .outlook)
        XCTAssertEqual(AccountClassifier.classify(kind: .subscribed, sourceTitle: "Subscribed Calendars"), .iCloud)
        XCTAssertNil(AccountClassifier.classify(kind: .local, sourceTitle: "On My iPhone"))
        XCTAssertNil(AccountClassifier.classify(kind: .birthdays, sourceTitle: "Other"))
        XCTAssertNil(AccountClassifier.classify(kind: .calDAV, sourceTitle: "Fastmail"))
    }
}
