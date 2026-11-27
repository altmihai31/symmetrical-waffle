import Foundation
import DaybookKit

/// In-memory sample data that mirrors the mockup. Only used for UI tests and screenshots,
/// because the simulator has no iCloud, Google or Outlook accounts.
@MainActor
final class DemoBackend: CalendarBackend {
    var onChange: (() -> Void)?
    private var cals: [CalendarInfo]
    private var lists: [CalendarInfo]
    private var allEvents: [CalEvent] = []
    private var allTasks: [TaskItem] = []
    private var nextID = 1000

    init(now: Date = Date(), calendar: Calendar) {
        cals = [
            CalendarInfo(id: "work", title: "Work", colorHex: "#2f6bff", account: .outlook),
            CalendarInfo(id: "personal", title: "Personal", colorHex: "#2fb35a", account: .iCloud),
            CalendarInfo(id: "family", title: "Family", colorHex: "#ff9500", account: .iCloud),
            CalendarInfo(id: "fitness", title: "Fitness", colorHex: "#ff2d55", account: .google),
            CalendarInfo(id: "holidays", title: "Holidays in Romania", colorHex: "#a259e6", account: .iCloud,
                         allowsModifications: false)
        ]
        lists = [
            CalendarInfo(id: "r-personal", title: "Personal", colorHex: "#2fb35a", account: .iCloud, isReminderList: true),
            CalendarInfo(id: "r-work", title: "Work", colorHex: "#2f6bff", account: .iCloud, isReminderList: true),
            CalendarInfo(id: "r-family", title: "Family", colorHex: "#ff9500", account: .iCloud, isReminderList: true)
        ]
        build(now: now, cal: calendar)
    }

    private func build(now: Date, cal: Calendar) {
        let today = cal.startOfDay(for: now)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let rangeStart = cal.date(byAdding: .day, value: -45, to: monthStart)!
        func at(_ day: Date, _ h: Int, _ m: Int = 0) -> Date { cal.date(byAdding: .minute, value: h * 60 + m, to: day)! }
        func add(_ title: String, _ c: String, _ s: Date, _ e: Date, allDay: Bool = false, loc: String? = nil,
                 notes: String? = nil, rep: RepeatRule = .never, alert: AlertOption = .none) {
            nextID += 1
            allEvents.append(CalEvent(id: "e\(nextID)", title: title, calendarID: c, start: s, end: e, isAllDay: allDay,
                                      location: loc, notes: notes, alert: alert, repeatRule: rep))
        }

        // Recurring routine for ~4 months around today.
        for offset in 0..<120 {
            let day = cal.date(byAdding: .day, value: offset, to: rangeStart)!
            let wd = cal.component(.weekday, from: day) // 1 = Sunday
            switch wd {
            case 2, 4, 6:
                add("Standup", "work", at(day, 9, 30), at(day, 9, 45), loc: "Zoom", rep: .weekly, alert: .min5)
            case 3:
                add("Gym: upper body", "fitness", at(day, 7), at(day, 8), loc: "World Class", rep: .weekly)
                add("Standup", "work", at(day, 9, 30), at(day, 9, 45), loc: "Zoom", rep: .weekly)
            case 5:
                add("Run 8 km", "fitness", at(day, 7), at(day, 7, 50), loc: "Herăstrău Park", rep: .weekly)
            case 7:
                add("Yoga", "fitness", at(day, 10), at(day, 11), loc: "Studio Prana", rep: .weekly)
            default: break
            }
            if wd == 2 { add("English lesson", "personal", at(day, 18), at(day, 19), rep: .weekly) }
        }

        // One-off events relative to today, like the mockup.
        let d = { (n: Int) in cal.date(byAdding: .day, value: n, to: today)! }
        add("Morning run", "fitness", at(d(0), 7), at(d(0), 7, 45))
        add("Product sync", "work", at(d(0), 11), at(d(0), 12), loc: "Room Danube", notes: "Agenda: Q1 roadmap, hiring")
        add("Lunch with Ana", "personal", at(d(0), 13), at(d(0), 14), loc: "Origo")
        add("Focus: Swift build", "work", at(d(0), 14, 30), at(d(0), 16, 30))
        add("Design review", "work", at(d(0), 15), at(d(0), 16), loc: "Zoom")
        add("Farmers' market", "personal", at(d(1), 9), at(d(1), 10, 30), loc: "Piața Obor")
        add("Jazz at Green Hours", "personal", at(d(1), 20), at(d(1), 22), loc: "Green Hours")
        add("Family brunch", "family", at(d(2), 11), at(d(2), 13), loc: "Mom's place")
        add("Dentist check-up", "personal", at(d(4), 16), at(d(4), 16, 45), loc: "Dr. Ionescu")
        add("Quarterly planning", "work", at(d(5), 10), at(d(5), 12, 30), loc: "Room Danube")
        add("Book club", "personal", at(d(6), 19), at(d(6), 21), loc: "Cărturești Carusel")
        add("Dinner with Ioana", "family", at(d(-3), 20), at(d(-3), 22), loc: "Kaiamo")
        add("Vet", "family", at(d(-7), 17), at(d(-7), 17, 30), loc: "VetCare")
        add("Haircut", "personal", at(d(-2), 12), at(d(-2), 12, 30))
        add("Flight OTP → BER", "personal", at(d(-15), 6, 40), at(d(-15), 8, 50), loc: "Otopeni Airport")
        add("Sprint review", "work", at(d(-21), 15), at(d(-21), 16))
        add("Mum's birthday", "family", d(-19), d(-18), allDay: true)
        add("Berlin trip", "personal", d(-15), d(-11), allDay: true, loc: "Berlin")
        add("Brașov weekend", "family", d(-7), d(-4), allDay: true, loc: "Brașov")
        add("Ski weekend", "family", d(15), d(18), allDay: true, loc: "Poiana Brașov")
        add("Christmas market", "family", d(9), d(10), allDay: true, loc: "Piața Constituției")

        // Romanian public holidays for this year and next.
        let year = cal.component(.year, from: today)
        for y in [year - 1, year, year + 1] {
            func h(_ m: Int, _ dd: Int, _ name: String, days: Int = 1) {
                let s = cal.date(from: DateComponents(year: y, month: m, day: dd))!
                add(name, "holidays", s, cal.date(byAdding: .day, value: days, to: s)!, allDay: true)
            }
            h(1, 1, "Anul Nou", days: 2)
            h(1, 24, "Ziua Unirii")
            h(5, 1, "Ziua Muncii")
            h(6, 1, "Ziua Copilului")
            h(8, 15, "Adormirea Maicii Domnului")
            h(11, 30, "Sfântul Andrei")
            h(12, 1, "Ziua Națională")
            h(12, 25, "Crăciunul", days: 2)
        }

        func task(_ title: String, _ list: String, _ due: Date?, time: Bool = false, done: Bool = false) {
            nextID += 1
            allTasks.append(TaskItem(id: "t\(nextID)", title: title, listID: list, due: due, dueHasTime: time,
                                     isCompleted: done, completionDate: done ? now : nil))
        }
        task("Send NDA to legal", "r-work", d(-2))
        task("Renew car insurance", "r-personal", d(-1))
        task("Water plants", "r-personal", d(0))
        task("Call the bank", "r-personal", at(d(0), 16), time: true)
        task("Gift for Mum", "r-family", d(-12), done: true)
        task("Groceries", "r-family", d(1))
        task("Invoices for November", "r-work", d(3))
        task("Plan December trip", "r-family", d(4))
        task("Fix bike brakes", "r-personal", d(-13), done: true)
        task("Pay rent", "r-personal", d(5))
        task("Book flights to Lisbon", "r-personal", nil)
        task("Read Swift concurrency notes", "r-work", nil)
    }

    func requestAccess() async -> (events: Bool, reminders: Bool) { (true, true) }
    func calendars() -> [CalendarInfo] { cals }
    func reminderLists() -> [CalendarInfo] { lists }

    func events(from: Date, to: Date) -> [CalEvent] {
        allEvents.filter { $0.end > from && $0.start < to }
    }

    func tasks() async -> [TaskItem] { allTasks }

    func save(_ event: CalEvent, isNew: Bool) throws -> CalEvent {
        var e = event
        if let i = allEvents.firstIndex(where: { $0.id == e.id }) {
            allEvents[i] = e
        } else {
            if isNew || e.id.isEmpty { nextID += 1; e.id = "e\(nextID)" }
            allEvents.append(e)
        }
        onChange?()
        return e
    }

    func delete(_ event: CalEvent) throws {
        allEvents.removeAll { $0.id == event.id }
        onChange?()
    }

    func save(_ task: TaskItem, isNew: Bool) throws -> TaskItem {
        var t = task
        if let i = allTasks.firstIndex(where: { $0.id == t.id }) {
            allTasks[i] = t
        } else {
            if isNew || t.id.isEmpty { nextID += 1; t.id = "t\(nextID)" }
            allTasks.append(t)
        }
        onChange?()
        return t
    }

    func delete(_ task: TaskItem) throws {
        allTasks.removeAll { $0.id == task.id }
        onChange?()
    }
}
