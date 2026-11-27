import Foundation

// MARK: - Month grid

/// The weeks shown for one month, starting on the calendar's first weekday.
public struct MonthGrid: Hashable, Sendable {
    /// First day of the month.
    public let month: Date
    /// Rows of seven start-of-day dates, including grey days from the months around it.
    public let weeks: [[Date]]

    public init(containing date: Date, calendar: Calendar) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let first = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        month = first
        let weekday = calendar.component(.weekday, from: first)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let rows = Int((Double(offset + daysInMonth) / 7.0).rounded(.up))
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: first) ?? first
        var weeks: [[Date]] = []
        for r in 0..<rows {
            var week: [Date] = []
            for c in 0..<7 {
                week.append(calendar.date(byAdding: .day, value: r * 7 + c, to: gridStart) ?? gridStart)
            }
            weeks.append(week)
        }
        self.weeks = weeks
    }

    public func isInMonth(_ day: Date, calendar: Calendar) -> Bool {
        calendar.isDate(day, equalTo: month, toGranularity: .month)
    }
}

public enum DateMath {
    /// The seven days of the week containing `date`.
    public static func week(containing date: Date, calendar: Calendar) -> [Date] {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: day) ?? day
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Weekday initials or short names in display order, e.g. Mon…Sun.
    public static func weekdaySymbols(calendar: Calendar, short: Bool = true) -> [String] {
        let symbols = short ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                            : ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let start = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(start + $0) % 7] }
    }

    /// The next whole hour after `now` on `day` (used as the default start of a new event).
    public static func nextRoundHour(on day: Date, now: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: now)
        let next = min(hour + 1, 23)
        let base = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .hour, value: next, to: base) ?? base
    }

    public static func minutesSinceStartOfDay(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Month starts shown in the month strip: `before` months before and `after` months after.
    public static func monthStrip(around date: Date, before: Int = 12, after: Int = 12, calendar: Calendar) -> [Date] {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let first = calendar.date(from: comps) ?? date
        return (-before...after).compactMap { calendar.date(byAdding: .month, value: $0, to: first) }
    }

    /// Moves `date` by one view period (day, week or month).
    public static func shift(_ date: Date, by value: Int, unit: Calendar.Component, calendar: Calendar) -> Date {
        calendar.date(byAdding: unit, value: value, to: date) ?? date
    }
}

// MARK: - Multi-day bars in the month grid

public struct BarSegment: Hashable, Sendable {
    public let eventID: String
    public let startColumn: Int
    /// Inclusive.
    public let endColumn: Int
    public let lane: Int
    public let continuesBefore: Bool
    public let continuesAfter: Bool
}

public enum MonthLayout {
    /// Lays out multi-day events as bars across one week row, stacking overlaps in lanes.
    public static func barSegments(week: [Date], events: [CalEvent], calendar: Calendar) -> [BarSegment] {
        guard let weekStart = week.first, let weekEnd = week.last else { return [] }
        let multi = events
            .filter { $0.isMultiDay(in: calendar) }
            .filter { ev in
                let days = ev.days(in: calendar)
                return days.last! >= weekStart && days.first! <= weekEnd
            }
            .sorted { a, b in
                if a.start != b.start { return a.start < b.start }
                let la = a.days(in: calendar).count, lb = b.days(in: calendar).count
                if la != lb { return la > lb }
                return a.id < b.id
            }
        var laneEnds: [Int] = [] // last occupied column per lane
        var result: [BarSegment] = []
        for ev in multi {
            let days = ev.days(in: calendar)
            let first = days.first!, last = days.last!
            let startCol = week.firstIndex(where: { $0 >= first }) ?? 0
            let endCol = week.lastIndex(where: { $0 <= last }) ?? 6
            var lane = laneEnds.firstIndex(where: { $0 < startCol }) ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(endCol) } else { laneEnds[lane] = endCol }
            lane = max(lane, 0)
            result.append(BarSegment(eventID: ev.id, startColumn: startCol, endColumn: endCol, lane: lane,
                                     continuesBefore: first < weekStart, continuesAfter: last > weekEnd))
        }
        return result
    }

    /// Lines reserved at the top of each column for bars (max lane + 1 among bars covering it).
    public static func reservedLanes(for segments: [BarSegment]) -> [Int] {
        var res = Array(repeating: 0, count: 7)
        for s in segments {
            for c in s.startColumn...s.endColumn where c >= 0 && c < 7 {
                res[c] = max(res[c], s.lane + 1)
            }
        }
        return res
    }
}

// MARK: - Entries for one day

public enum DayItem: Hashable, Sendable, Identifiable {
    case allDay(CalEvent)
    case timed(CalEvent)
    case task(TaskItem)

    public var id: String {
        switch self {
        case .allDay(let e): return "a-" + e.id
        case .timed(let e): return "t-" + e.id
        case .task(let t): return "k-" + t.id
        }
    }

    public var title: String {
        switch self {
        case .allDay(let e), .timed(let e): return e.title
        case .task(let t): return t.title
        }
    }
}

public enum DayContent {
    /// Single-day entries for a day in display order: all-day events, timed events by start,
    /// then tasks (multi-day events are drawn as bars and left out).
    public static func items(on day: Date, events: [CalEvent], tasks: [TaskItem],
                             includeTasks: Bool, includeMultiDay: Bool = false,
                             calendar: Calendar) -> [DayItem] {
        let dayEvents = events.filter { $0.occurs(on: day, in: calendar) }
        let singles = dayEvents.filter { includeMultiDay || !$0.isMultiDay(in: calendar) }
        let allDay = singles.filter { $0.isAllDay }.sorted { $0.title < $1.title }.map(DayItem.allDay)
        let timed = singles.filter { !$0.isAllDay }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.title < $1.title }
            .map(DayItem.timed)
        var result = allDay + timed
        if includeTasks {
            let dayTasks = tasks.filter { t in
                guard let due = t.due else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }.sorted { a, b in
                if a.isCompleted != b.isCompleted { return !a.isCompleted }
                switch (a.dueHasTime, b.dueHasTime) {
                case (true, true): return a.due! < b.due!
                case (true, false): return true
                case (false, true): return false
                default: return a.title < b.title
                }
            }
            result += dayTasks.map(DayItem.task)
        }
        return result
    }
}

// MARK: - Timeline (Day and Week)

public struct TimelineSlot: Hashable, Sendable {
    public let eventID: String
    public let startMinute: Int
    public let endMinute: Int
    public let column: Int
    public let columnCount: Int
}

public enum TimelineLayout {
    public static let minimumMinutes = 20

    /// Places the timed events of one day side by side where they overlap.
    public static func slots(for day: Date, events: [CalEvent], calendar: Calendar) -> [TimelineSlot] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        struct Item { let id: String; let s: Int; let e: Int }
        let items: [Item] = events
            .filter { !$0.isAllDay && $0.start < dayEnd && $0.end > dayStart }
            .map { ev in
                let s = max(0, Int(ev.start.timeIntervalSince(dayStart) / 60))
                var e = min(24 * 60, Int(ev.end.timeIntervalSince(dayStart) / 60))
                if e - s < minimumMinutes { e = min(24 * 60, s + minimumMinutes) }
                return Item(id: ev.id, s: s, e: e)
            }
            .sorted { $0.s != $1.s ? $0.s < $1.s : ($0.e != $1.e ? $0.e > $1.e : $0.id < $1.id) }

        var result: [TimelineSlot] = []
        var cluster: [(Item, Int)] = []
        var clusterEnd = -1
        var columnEnds: [Int] = []

        func flush() {
            let count = max(1, columnEnds.count)
            for (item, col) in cluster {
                result.append(TimelineSlot(eventID: item.id, startMinute: item.s, endMinute: item.e,
                                           column: col, columnCount: count))
            }
            cluster.removeAll()
            columnEnds.removeAll()
            clusterEnd = -1
        }

        for item in items {
            if !cluster.isEmpty && item.s >= clusterEnd { flush() }
            let col = columnEnds.firstIndex(where: { $0 <= item.s }) ?? columnEnds.count
            if col == columnEnds.count { columnEnds.append(item.e) } else { columnEnds[col] = item.e }
            cluster.append((item, col))
            clusterEnd = max(clusterEnd, item.e)
        }
        flush()
        return result
    }
}

// MARK: - Tasks tab

public enum TaskGroup: String, CaseIterable, Hashable, Sendable {
    case overdue = "Overdue"
    case today = "Today"
    case upcoming = "Upcoming"
    case noDate = "No date"
    case done = "Done"
}

public enum TaskGrouping {
    public static func group(_ tasks: [TaskItem], now: Date, calendar: Calendar) -> [(group: TaskGroup, tasks: [TaskItem])] {
        var buckets: [TaskGroup: [TaskItem]] = [:]
        let today = calendar.startOfDay(for: now)
        for t in tasks {
            let g: TaskGroup
            if t.isCompleted { g = .done }
            else if t.due == nil { g = .noDate }
            else if t.isOverdue(now: now, calendar: calendar) { g = .overdue }
            else if calendar.isDate(t.due!, inSameDayAs: today) { g = .today }
            else { g = .upcoming }
            buckets[g, default: []].append(t)
        }
        let byDue: (TaskItem, TaskItem) -> Bool = { a, b in
            switch (a.due, b.due) {
            case let (x?, y?) where x != y: return x < y
            default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
        return TaskGroup.allCases.compactMap { g in
            guard var list = buckets[g], !list.isEmpty else { return nil }
            if g == .done {
                list.sort { ($0.completionDate ?? .distantPast) > ($1.completionDate ?? .distantPast) }
            } else {
                list.sort(by: byDue)
            }
            return (g, list)
        }
    }
}

// MARK: - List (agenda) and search

public struct AgendaSection: Hashable, Sendable, Identifiable {
    public let day: Date
    public let title: String
    public let items: [DayItem]
    public var id: Date { day }
}

public enum Agenda {
    /// Days from `from` for `days` days that have something on them.
    public static func sections(from: Date, days: Int, events: [CalEvent], tasks: [TaskItem],
                                includeTasks: Bool, now: Date, calendar: Calendar) -> [AgendaSection] {
        let start = calendar.startOfDay(for: from)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let items = DayContent.items(on: day, events: events, tasks: tasks, includeTasks: includeTasks,
                                         includeMultiDay: true, calendar: calendar)
            guard !items.isEmpty else { return nil }
            return AgendaSection(day: day, title: DateText.dayHeader(day, now: now, calendar: calendar), items: items)
        }
    }
}

public enum Search {
    public static func matches(_ query: String, in fields: [String?]) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }
        return fields.contains { field in
            guard let field else { return false }
            return field.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Events and tasks whose title, location or calendar name contains the query, grouped by day.
    public static func results(_ query: String, events: [CalEvent], tasks: [TaskItem],
                               calendars: [CalendarInfo], now: Date, calendar: Calendar) -> [AgendaSection] {
        let names = Dictionary(calendars.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
        var byDay: [Date: [DayItem]] = [:]
        for e in events where matches(query, in: [e.title, e.location, names[e.calendarID]]) {
            byDay[calendar.startOfDay(for: e.start), default: []].append(e.isAllDay ? .allDay(e) : .timed(e))
        }
        var undated: [DayItem] = []
        for t in tasks where matches(query, in: [t.title, t.notes, names[t.listID]]) {
            if let due = t.due { byDay[calendar.startOfDay(for: due), default: []].append(.task(t)) }
            else { undated.append(.task(t)) }
        }
        var sections = byDay.keys.sorted().map { day in
            AgendaSection(day: day, title: DateText.dayHeader(day, now: now, calendar: calendar), items: byDay[day]!)
        }
        if !undated.isEmpty {
            sections.append(AgendaSection(day: .distantFuture, title: "No date", items: undated))
        }
        return sections
    }
}

// MARK: - Text formatting

public enum DateText {
    static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                             "August", "September", "October", "November", "December"]
    static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    public static func monthName(_ date: Date, calendar: Calendar, short: Bool = false) -> String {
        let name = monthNames[calendar.component(.month, from: date) - 1]
        return short ? String(name.prefix(3)) : name
    }

    public static func year(_ date: Date, calendar: Calendar) -> String {
        String(calendar.component(.year, from: date))
    }

    /// "Today", "Tomorrow", "Yesterday", or e.g. "Monday 30 Nov".
    public static func dayHeader(_ day: Date, now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        let d = calendar.startOfDay(for: day)
        let diff = calendar.dateComponents([.day], from: today, to: d).day ?? 0
        switch diff {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return longDay(d, calendar: calendar)
        }
    }

    /// e.g. "Monday 30 Nov", with the year added when it is not `now`'s year.
    public static func longDay(_ day: Date, calendar: Calendar, now: Date? = nil) -> String {
        let wd = weekdayNames[calendar.component(.weekday, from: day) - 1]
        let dd = calendar.component(.day, from: day)
        var s = "\(wd) \(dd) \(monthName(day, calendar: calendar, short: true))"
        if let now, calendar.component(.year, from: now) != calendar.component(.year, from: day) {
            s += " \(year(day, calendar: calendar))"
        }
        return s
    }

    /// e.g. "Fri 27 Nov".
    public static func shortDay(_ day: Date, calendar: Calendar) -> String {
        let wd = String(weekdayNames[calendar.component(.weekday, from: day) - 1].prefix(3))
        return "\(wd) \(calendar.component(.day, from: day)) \(monthName(day, calendar: calendar, short: true))"
    }

    /// "13:05" in 24-hour time, "1:05pm" in 12-hour time.
    public static func time(_ date: Date, use24h: Bool, calendar: Calendar) -> String {
        time(minutes: DateMath.minutesSinceStartOfDay(date, calendar: calendar), use24h: use24h)
    }

    public static func time(minutes: Int, use24h: Bool) -> String {
        let h = (minutes / 60) % 24, m = minutes % 60
        if use24h { return String(format: "%02d:%02d", h, m) }
        let h12 = h % 12 == 0 ? 12 : h % 12
        let suffix = h < 12 ? "am" : "pm"
        return m == 0 ? "\(h12)\(suffix)" : String(format: "%d:%02d%@", h12, m, suffix)
    }

    /// Short duration text, e.g. "1h", "45m", "1h 30m".
    public static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    /// The time line for an event in lists and the detail sheet.
    public static func eventTimeRange(_ e: CalEvent, use24h: Bool, calendar: Calendar) -> String {
        let days = e.days(in: calendar)
        if e.isAllDay {
            if days.count > 1 {
                return "\(shortDay(days.first!, calendar: calendar)) – \(shortDay(days.last!, calendar: calendar))"
            }
            return "All day"
        }
        let s = time(e.start, use24h: use24h, calendar: calendar)
        let en = time(e.end, use24h: use24h, calendar: calendar)
        if days.count > 1 {
            return "\(shortDay(days.first!, calendar: calendar)) \(s) – \(shortDay(days.last!, calendar: calendar)) \(en)"
        }
        return "\(s) – \(en)"
    }
}
