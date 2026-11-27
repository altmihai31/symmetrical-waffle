import XCTest

/// Drives the app with demo data and saves a screenshot of every screen.
/// Screenshots go to $SCREENSHOT_DIR (passed by CI as TEST_RUNNER_SCREENSHOT_DIR) and into the test results.
final class DaybookUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-DaybookDemo", "YES", "-DaybookResetDefaults", "YES",
                                "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "Missing \(id)", file: file, line: line)
        e.tap()
    }

    private func snap(_ name: String) {
        // Let animations settle.
        Thread.sleep(forTimeInterval: 0.8)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: url)
        }
    }

    func testTourOfScreens() {
        app.launch()
        XCTAssertTrue(el("monthView").waitForExistence(timeout: 15))
        snap("01-month")

        tap("tab-Week"); XCTAssertTrue(el("weekView").waitForExistence(timeout: 5)); snap("02-week")
        tap("tab-Day"); XCTAssertTrue(el("dayView").waitForExistence(timeout: 5)); snap("03-day")
        tap("tab-List"); XCTAssertTrue(el("listView").waitForExistence(timeout: 5)); snap("04-list")
        tap("tab-Tasks"); XCTAssertTrue(el("tasksView").waitForExistence(timeout: 5)); snap("05-tasks")

        // Event detail, then the editor in the same sheet.
        tap("tab-List")
        tap("row-Product sync")
        XCTAssertTrue(el("detailTitle").waitForExistence(timeout: 5))
        snap("06-event-detail")
        tap("pill-Edit")
        XCTAssertTrue(el("titleField").waitForExistence(timeout: 5))
        snap("07-edit-event")
        tap("when-start")
        XCTAssertTrue(el("wheel").waitForExistence(timeout: 5))
        snap("08-edit-event-wheels")
        tap("closeButton")

        // New event typed in natural language.
        tap("tab-Month")
        tap("addButton")
        let title = el("titleField")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        snap("09a-new-event-empty")
        title.tap()
        // Type word by word, like a person: the field re-lays out as the parser
        // highlights words and wraps to a second line, and a single fast burst can drop keys.
        for word in ["Coffee ", "with ", "Radu ", "tomorrow ", "1pm ", "at ", "Origo ", "#family"] {
            title.typeText(word)
        }
        XCTAssertEqual(title.value as? String, "Coffee with Radu tomorrow 1pm at Origo #family")
        XCTAssertTrue(el("when-start").waitForExistence(timeout: 5))
        snap("09-new-event-parsed")
        tap("pill-Save")
        XCTAssertTrue(el("toast").waitForExistence(timeout: 5))
        snap("10-month-after-save")

        // The new event shows up in the list with the parsed title and place.
        tap("tab-List")
        let row = el("row-Coffee with Radu")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Origo"), "Location should be parsed: \(row.label)")

        // Drawer and settings.
        tap("menuButton")
        XCTAssertTrue(el("drawer").waitForExistence(timeout: 5))
        snap("11-drawer")
        tap("drawer-Calendars & settings")
        XCTAssertTrue(el("settingsView").waitForExistence(timeout: 5))
        snap("12-settings")
        tap("closeButton")

        // Search.
        tap("searchButton")
        let field = el("searchField")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("yoga")
        XCTAssertTrue(el("searchResults").waitForExistence(timeout: 5))
        snap("13-search")
        tap("searchButton")

        // Complete a task.
        tap("tab-Tasks")
        tap("check-Water plants")
        XCTAssertTrue(el("toast").waitForExistence(timeout: 5))
        snap("14-task-completed")
    }

    /// A finger drag across a row, slower than XCUITest's swipe flick.
    private func drag(_ e: XCUIElement, from x0: CGFloat, to x1: CGFloat) {
        let start = e.coordinate(withNormalizedOffset: CGVector(dx: x0, dy: 0.5))
        let end = e.coordinate(withNormalizedOffset: CGVector(dx: x1, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 600, thenHoldForDuration: 0.1)
    }

    private func text(beginningWith prefix: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    func testSwipeAndDragGestures() {
        app.launch()
        XCTAssertTrue(el("monthView").waitForExistence(timeout: 15))

        // Swipe a task right to complete it, and left to postpone it.
        tap("tab-Tasks")
        let rent = el("task-Pay rent")
        XCTAssertTrue(rent.waitForExistence(timeout: 5))
        drag(rent, from: 0.3, to: 0.9)
        XCTAssertTrue(text(beginningWith: "Task completed").waitForExistence(timeout: 5))
        let groceries = el("task-Groceries")
        XCTAssertTrue(groceries.waitForExistence(timeout: 5))
        drag(groceries, from: 0.8, to: 0.15)
        let postponed = text(beginningWith: "Postponed to").waitForExistence(timeout: 5)
        snap("17-task-swiped")
        XCTAssertTrue(postponed)

        // Swipe an event left to delete it.
        tap("tab-List")
        let run = el("row-Morning run")
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        drag(run, from: 0.8, to: 0.15)
        let deleted = text(beginningWith: "Event deleted").waitForExistence(timeout: 5)
        snap("18-event-swiped")
        XCTAssertTrue(deleted)

        // Long-press a week tile and drop it on the first day.
        tap("tab-Week")
        XCTAssertTrue(el("weekView").waitForExistence(timeout: 5))
        let target = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'weekday-'")).firstMatch
        let tile = el("tile-Book club")
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        tile.press(forDuration: 1.0, thenDragTo: target, withVelocity: 300, thenHoldForDuration: 0.5)
        let moved = text(beginningWith: "Moved to").waitForExistence(timeout: 5)
        snap("19-week-after-drag")
        XCTAssertTrue(moved)

        // Tap the selected month cell to zoom into its Day view.
        tap("tab-Month")
        XCTAssertTrue(el("monthView").waitForExistence(timeout: 5))
        let key = DateFormatter()
        key.calendar = Calendar(identifier: .gregorian)
        key.locale = Locale(identifier: "en_US_POSIX")
        key.dateFormat = "yyyy-MM-dd"
        tap("day-\(key.string(from: Date()))")
        XCTAssertTrue(el("dayView").waitForExistence(timeout: 5))
        snap("20-day-after-zoom")
    }

    /// The ideas from the Calendars study: peek, compact card, drawing an event, celebration.
    func testStudyFeatures() {
        app.launch()
        XCTAssertTrue(el("monthView").waitForExistence(timeout: 15))
        let key = DateFormatter()
        key.calendar = Calendar(identifier: .gregorian)
        key.locale = Locale(identifier: "en_US_POSIX")
        key.dateFormat = "yyyy-MM-dd"

        // Press and hold a month day to peek at its agenda.
        let today = el("day-\(key.string(from: Date()))")
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).press(forDuration: 1.3)
        snap("21-month-peek")
        let open = app.buttons["Open day"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(el("dayView").waitForExistence(timeout: 5))

        // Tapping an event opens the compact card first.
        tap("tab-List")
        tap("row-Product sync")
        XCTAssertTrue(el("detailTitle").waitForExistence(timeout: 5))
        XCTAssertTrue(el("pill-Edit").waitForExistence(timeout: 5))
        snap("22-event-card")
        tap("pill-Edit")
        XCTAssertTrue(el("titleField").waitForExistence(timeout: 5))
        tap("closeButton")

        // Touch and hold empty time in the Day view, then drag down to set the length.
        tap("tab-Day")
        let day = el("dayView")
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        let free = [13, 14, 20, 21, 8, 12, 19, 22, 17, 18, 23, 6, 5, 4, 3, 2, 1]
        let bottom = day.frame.maxY
        guard let hour = free.map({ el("hour-\($0)") }).first(where: { $0.exists && $0.isHittable && $0.frame.maxY + 100 < bottom })
        else { return XCTFail("No free hour on screen") }
        let start = hour.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.15))
        start.press(forDuration: 0.9, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 75)),
                    withVelocity: 120, thenHoldForDuration: 0.4)
        XCTAssertTrue(el("titleField").waitForExistence(timeout: 5))
        XCTAssertTrue(el("when-start").waitForExistence(timeout: 5), "A drawn event shows its times")
        snap("23-drawn-event")
        tap("closeButton")

        // Ticking today's last open task plays the celebration.
        tap("tab-Tasks")
        for t in ["Send NDA to legal", "Renew car insurance", "Water plants"] {
            tap("check-\(t)")
            Thread.sleep(forTimeInterval: 0.6)
        }
        tap("check-Call the bank")
        XCTAssertTrue(el("celebration").waitForExistence(timeout: 3))
        snap("24-celebration")
        XCTAssertTrue(el("allDone").waitForExistence(timeout: 5))
        snap("25-all-done")
    }

    func testLightMode() {
        app.launchArguments += ["-daybook.appearance", "Light"]
        app.launch()
        XCTAssertTrue(el("monthView").waitForExistence(timeout: 15))
        snap("15-month-light")
        tap("tab-Day")
        snap("16-day-light")
    }

    func testHidingCalendarRemovesItsEvents() {
        app.launch()
        tap("tab-List")
        XCTAssertTrue(el("row-Product sync").waitForExistence(timeout: 5))
        tap("menuButton")
        let toggle = el("toggle-Work")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertFalse(el("row-Product sync").waitForExistence(timeout: 2))
    }
}
