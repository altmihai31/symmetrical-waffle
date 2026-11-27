import EventKit
import UIKit
import DaybookKit

/// Reads and writes the user's iCloud, Google and Outlook calendars and Apple Reminders.
@MainActor
final class EventKitBackend: CalendarBackend {
    let store = EKEventStore()
    var onChange: (() -> Void)?
    private var observer: NSObjectProtocol?
    /// Occurrence id -> event, so edits reach the right occurrence of a repeating event.
    private var eventCache: [String: EKEvent] = [:]
    private var reminderCache: [String: EKReminder] = [:]
    private let colorKey = "daybook.customEventColors"

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onChange?() }
        }
    }

    func requestAccess() async -> (events: Bool, reminders: Bool) {
        let ev = (try? await store.requestFullAccessToEvents()) ?? false
        let rem = (try? await store.requestFullAccessToReminders()) ?? false
        return (ev, rem)
    }

    // MARK: Calendars

    private func account(for source: EKSource?) -> AccountKind? {
        guard let source else { return nil }
        let kind: AccountClassifier.SourceKind
        switch source.sourceType {
        case .local: kind = .local
        case .exchange: kind = .exchange
        case .calDAV: kind = .calDAV
        case .mobileMe: kind = .mobileMe
        case .subscribed: kind = .subscribed
        case .birthdays: kind = .birthdays
        @unknown default: kind = .other
        }
        return AccountClassifier.classify(kind: kind, sourceTitle: source.title)
    }

    private func info(_ c: EKCalendar, reminders: Bool) -> CalendarInfo? {
        guard let acc = account(for: c.source) else { return nil }
        return CalendarInfo(id: c.calendarIdentifier, title: c.title, colorHex: UIColor(cgColor: c.cgColor).hexString,
                            account: acc, allowsModifications: c.allowsContentModifications,
                            isReminderList: reminders)
    }

    private var supportedEventCalendars: [EKCalendar] {
        store.calendars(for: .event).filter { account(for: $0.source) != nil }
    }

    private var supportedReminderLists: [EKCalendar] {
        store.calendars(for: .reminder).filter { account(for: $0.source) != nil }
    }

    func calendars() -> [CalendarInfo] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        return supportedEventCalendars.compactMap { info($0, reminders: false) }
    }

    func reminderLists() -> [CalendarInfo] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
        return supportedReminderLists.compactMap { info($0, reminders: true) }
    }

    // MARK: Events

    private var customColors: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: colorKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: colorKey) }
    }

    private static func occurrenceID(_ e: EKEvent) -> String {
        let base = e.eventIdentifier ?? e.calendarItemIdentifier
        let stamp = Int((e.occurrenceDate ?? e.startDate).timeIntervalSince1970)
        return "\(base)@\(stamp)"
    }

    private func repeatRule(of e: EKEvent) -> RepeatRule {
        guard let r = e.recurrenceRules?.first else { return .never }
        switch r.frequency {
        case .daily: return .daily
        case .weekly: return r.interval == 2 ? .biweekly : .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        @unknown default: return .never
        }
    }

    private func convert(_ e: EKEvent) -> CalEvent {
        let id = Self.occurrenceID(e)
        let alertMinutes = e.alarms?.first.map { Int(-$0.relativeOffset / 60) }
        let attendees = (e.attendees ?? []).compactMap { $0.name ?? $0.url.absoluteString.replacingOccurrences(of: "mailto:", with: "") }
        return CalEvent(id: id, title: e.title ?? "", calendarID: e.calendar.calendarIdentifier,
                        start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
                        location: e.location, notes: e.notes,
                        alert: AlertOption.closest(toMinutesBefore: alertMinutes),
                        repeatRule: repeatRule(of: e),
                        customColorHex: e.eventIdentifier.flatMap { customColors[$0] },
                        url: e.url?.absoluteString, attendees: attendees)
    }

    func events(from: Date, to: Date) -> [CalEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let cals = supportedEventCalendars
        guard !cals.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: cals)
        let found = store.events(matching: predicate)
        eventCache.removeAll()
        return found.map { ek in
            let ce = convert(ek)
            eventCache[ce.id] = ek
            return ce
        }
    }

    private func apply(_ e: CalEvent, to ek: EKEvent) throws {
        guard let cal = store.calendar(withIdentifier: e.calendarID) else { throw BackendError.notFound }
        guard cal.allowsContentModifications else { throw BackendError.readOnlyCalendar }
        ek.title = e.title
        ek.calendar = cal
        ek.isAllDay = e.isAllDay
        ek.startDate = e.start
        ek.endDate = e.isAllDay ? e.end.addingTimeInterval(-1) : e.end
        ek.location = e.location?.isEmpty == true ? nil : e.location
        ek.notes = e.notes?.isEmpty == true ? nil : e.notes
        ek.url = e.url.flatMap { URL(string: $0) }
        ek.alarms?.forEach { ek.removeAlarm($0) }
        if e.alert != .none { ek.addAlarm(EKAlarm(relativeOffset: TimeInterval(-e.alert.rawValue * 60))) }
        ek.recurrenceRules?.forEach { ek.removeRecurrenceRule($0) }
        let rule: EKRecurrenceRule?
        switch e.repeatRule {
        case .never: rule = nil
        case .daily: rule = EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly: rule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .biweekly: rule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly: rule = EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .yearly: rule = EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
        if let rule { ek.addRecurrenceRule(rule) }
    }

    func save(_ event: CalEvent, isNew: Bool) throws -> CalEvent {
        let ek: EKEvent
        var span: EKSpan = .thisEvent
        if !isNew, let cached = eventCache[event.id] {
            ek = cached
            if repeatRule(of: cached) != event.repeatRule { span = .futureEvents }
        } else {
            ek = EKEvent(eventStore: store)
        }
        try apply(event, to: ek)
        try store.save(ek, span: span, commit: true)
        if let key = ek.eventIdentifier {
            var colors = customColors
            colors[key] = event.customColorHex
            customColors = colors
        }
        let saved = convert(ek)
        eventCache[saved.id] = ek
        return saved
    }

    func delete(_ event: CalEvent) throws {
        guard let ek = eventCache[event.id] else { throw BackendError.notFound }
        try store.remove(ek, span: .thisEvent, commit: true)
    }

    // MARK: Reminders

    private func convert(_ r: EKReminder) -> TaskItem {
        var due: Date?
        var hasTime = false
        if let comps = r.dueDateComponents {
            due = Calendar.current.date(from: comps)
            hasTime = comps.hour != nil
        }
        return TaskItem(id: r.calendarItemIdentifier, title: r.title ?? "", listID: r.calendar.calendarIdentifier,
                        due: due, dueHasTime: hasTime, notes: r.notes,
                        isCompleted: r.isCompleted, completionDate: r.completionDate)
    }

    private func fetch(_ predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { result in
                cont.resume(returning: result ?? [])
            }
        }
    }

    func tasks() async -> [TaskItem] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
        let lists = supportedReminderLists
        guard !lists.isEmpty else { return [] }
        let open = await fetch(store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: lists))
        let since = Calendar.current.date(byAdding: .day, value: -60, to: Date())
        let done = await fetch(store.predicateForCompletedReminders(withCompletionDateStarting: since, ending: nil, calendars: lists))
        reminderCache.removeAll()
        return (open + done).map { r in
            reminderCache[r.calendarItemIdentifier] = r
            return convert(r)
        }
    }

    func save(_ task: TaskItem, isNew: Bool) throws -> TaskItem {
        let r: EKReminder
        if !isNew, let cached = reminderCache[task.id] {
            r = cached
        } else if !isNew, let item = store.calendarItem(withIdentifier: task.id) as? EKReminder {
            r = item
        } else {
            r = EKReminder(eventStore: store)
        }
        guard let list = store.calendar(withIdentifier: task.listID) else { throw BackendError.notFound }
        r.calendar = list
        r.title = task.title
        r.notes = task.notes?.isEmpty == true ? nil : task.notes
        if let due = task.due {
            let units: Set<Calendar.Component> = task.dueHasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
            r.dueDateComponents = Calendar.current.dateComponents(units, from: due)
        } else {
            r.dueDateComponents = nil
        }
        r.isCompleted = task.isCompleted
        try store.save(r, commit: true)
        reminderCache[r.calendarItemIdentifier] = r
        return convert(r)
    }

    func delete(_ task: TaskItem) throws {
        guard let r = reminderCache[task.id] ?? store.calendarItem(withIdentifier: task.id) as? EKReminder else {
            throw BackendError.notFound
        }
        try store.remove(r, commit: true)
    }
}
