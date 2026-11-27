import Foundation

/// The account a calendar or Reminders list lives in. Daybook only shows these three.
public enum AccountKind: String, Codable, CaseIterable, Sendable {
    case iCloud
    case google
    case outlook

    public var label: String {
        switch self {
        case .iCloud: return "iCloud"
        case .google: return "Google"
        case .outlook: return "Outlook"
        }
    }
}

/// A calendar (for events) or a Reminders list (for tasks).
public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var colorHex: String
    public var account: AccountKind
    public var isVisible: Bool
    public var allowsModifications: Bool
    public var isReminderList: Bool

    public init(id: String, title: String, colorHex: String, account: AccountKind,
                isVisible: Bool = true, allowsModifications: Bool = true, isReminderList: Bool = false) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.account = account
        self.isVisible = isVisible
        self.allowsModifications = allowsModifications
        self.isReminderList = isReminderList
    }
}

public enum AlertOption: Int, CaseIterable, Hashable, Sendable, Identifiable {
    case none = -1
    case atTime = 0
    case min5 = 5
    case min15 = 15
    case min30 = 30
    case hour1 = 60
    case day1 = 1440

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .none: return "None"
        case .atTime: return "At time of event"
        case .min5: return "5 minutes before"
        case .min15: return "15 minutes before"
        case .min30: return "30 minutes before"
        case .hour1: return "1 hour before"
        case .day1: return "1 day before"
        }
    }

    /// Picks the closest option for an offset in minutes before the event (nil = no alert).
    public static func closest(toMinutesBefore minutes: Int?) -> AlertOption {
        guard let minutes else { return .none }
        let options = AlertOption.allCases.filter { $0 != .none }
        return options.min(by: { abs($0.rawValue - minutes) < abs($1.rawValue - minutes) }) ?? .none
    }
}

public enum RepeatRule: String, CaseIterable, Hashable, Sendable, Identifiable {
    case never, daily, weekly, biweekly, monthly, yearly

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

/// A calendar event. For all-day events `start` is the start of the first day and `end`
/// is either the start of the day after the last day or a moment inside the last day.
public struct CalEvent: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var calendarID: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var alert: AlertOption
    public var repeatRule: RepeatRule
    public var customColorHex: String?
    public var url: String?
    public var attendees: [String]

    public init(id: String, title: String, calendarID: String, start: Date, end: Date,
                isAllDay: Bool = false, location: String? = nil, notes: String? = nil,
                alert: AlertOption = .none, repeatRule: RepeatRule = .never,
                customColorHex: String? = nil, url: String? = nil, attendees: [String] = []) {
        self.id = id
        self.title = title
        self.calendarID = calendarID
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.alert = alert
        self.repeatRule = repeatRule
        self.customColorHex = customColorHex
        self.url = url
        self.attendees = attendees
    }

    /// The days this event touches, as start-of-day dates.
    public func days(in calendar: Calendar) -> [Date] {
        let first = calendar.startOfDay(for: start)
        let lastMoment = end > start ? end.addingTimeInterval(-1) : start
        let last = calendar.startOfDay(for: lastMoment)
        var result: [Date] = []
        var day = first
        while day <= last {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result.isEmpty ? [first] : result
    }

    public func isMultiDay(in calendar: Calendar) -> Bool {
        days(in: calendar).count > 1
    }

    public func occurs(on day: Date, in calendar: Calendar) -> Bool {
        let d = calendar.startOfDay(for: day)
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end > start ? end.addingTimeInterval(-1) : start)
        return d >= first && d <= last
    }
}

/// A task, backed by an Apple Reminders item.
public struct TaskItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var listID: String
    public var due: Date?
    public var dueHasTime: Bool
    public var notes: String?
    public var isCompleted: Bool
    public var completionDate: Date?

    public init(id: String, title: String, listID: String, due: Date? = nil, dueHasTime: Bool = false,
                notes: String? = nil, isCompleted: Bool = false, completionDate: Date? = nil) {
        self.id = id
        self.title = title
        self.listID = listID
        self.due = due
        self.dueHasTime = dueHasTime
        self.notes = notes
        self.isCompleted = isCompleted
        self.completionDate = completionDate
    }

    public func isOverdue(now: Date, calendar: Calendar) -> Bool {
        guard !isCompleted, let due else { return false }
        if dueHasTime { return due < now }
        return calendar.startOfDay(for: due) < calendar.startOfDay(for: now)
    }
}

/// User settings. Defaults follow the spec: Monday start, 24-hour time, tasks shown.
public struct DaybookSettings: Hashable, Sendable {
    public var weekStartsOnMonday: Bool = true
    public var use24HourTime: Bool = true
    public var showTasksInCalendar: Bool = true
    public var defaultEventMinutes: Int = 60
    public var defaultAlert: AlertOption = .none

    public init() {}

    /// A Gregorian calendar set to the chosen first weekday.
    public func calendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        // Set the locale first: assigning a locale resets firstWeekday to the locale's default.
        cal.locale = Locale(identifier: "en_GB")
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1
        cal.minimumDaysInFirstWeek = 4
        return cal
    }
}
