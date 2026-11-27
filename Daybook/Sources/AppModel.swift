import SwiftUI
import DaybookKit

enum ViewMode: String, CaseIterable, Identifiable {
    case tasks = "Tasks", list = "List", day = "Day", week = "Week", month = "Month"
    var id: String { rawValue }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// What a bottom sheet is showing.
enum SheetRoute: Identifiable {
    case event(CalEvent)              // detail, can switch to edit
    case newEvent(start: Date, end: Date, allDay: Bool)
    case task(TaskItem?, defaultDue: Date?)
    case settings

    var id: String {
        switch self {
        case .event(let e): return "event-\(e.id)"
        case .newEvent(let s, _, _): return "new-\(s.timeIntervalSince1970)"
        case .task(let t, _): return "task-\(t?.id ?? "new")"
        case .settings: return "settings"
        }
    }
}

struct UndoToast: Identifiable {
    let id = UUID()
    let message: String
    let undo: (() -> Void)?
}

@MainActor
final class AppModel: ObservableObject {
    // Navigation state
    @Published var mode: ViewMode = .month
    @Published var selectedDate: Date
    @Published var sheet: SheetRoute?
    @Published var drawerOpen = false
    @Published var searchOpen = false
    @Published var searchText = ""
    @Published var toast: UndoToast?
    @Published var errorMessage: String?

    // Data
    @Published private(set) var calendars: [CalendarInfo] = []
    @Published private(set) var reminderLists: [CalendarInfo] = []
    @Published private(set) var events: [CalEvent] = []
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var access: AccessState = .unknown
    @Published var hiddenCalendarIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: Keys.hidden) }
    }

    // Settings
    @Published var settings: DaybookSettings {
        didSet { saveSettings(); reloadEvents() }
    }
    @Published var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    let isDemo: Bool
    private let backend: CalendarBackend
    private var loadedRange: ClosedRange<Date>?
    private var toastTask: Task<Void, Never>?

    private enum Keys {
        static let hidden = "daybook.hiddenCalendars"
        static let appearance = "daybook.appearance"
        static let weekMonday = "daybook.weekStartsMonday"
        static let use24h = "daybook.use24h"
        static let showTasks = "daybook.showTasks"
        static let defaultLength = "daybook.defaultLength"
        static let defaultAlert = "daybook.defaultAlert"
    }

    var calendar: Calendar { settings.calendar() }
    var now: Date { Date() }

    init(demo: Bool) {
        isDemo = demo
        let d = UserDefaults.standard
        var s = DaybookSettings()
        if d.object(forKey: Keys.weekMonday) != nil { s.weekStartsOnMonday = d.bool(forKey: Keys.weekMonday) }
        if d.object(forKey: Keys.use24h) != nil { s.use24HourTime = d.bool(forKey: Keys.use24h) }
        if d.object(forKey: Keys.showTasks) != nil { s.showTasksInCalendar = d.bool(forKey: Keys.showTasks) }
        if d.object(forKey: Keys.defaultLength) != nil { s.defaultEventMinutes = max(15, d.integer(forKey: Keys.defaultLength)) }
        if d.object(forKey: Keys.defaultAlert) != nil { s.defaultAlert = AlertOption(rawValue: d.integer(forKey: Keys.defaultAlert)) ?? .none }
        settings = s
        appearance = Appearance(rawValue: d.string(forKey: Keys.appearance) ?? "") ?? .dark
        hiddenCalendarIDs = Set(d.stringArray(forKey: Keys.hidden) ?? [])
        selectedDate = s.calendar().startOfDay(for: Date())
        backend = demo ? DemoBackend(calendar: s.calendar()) : EventKitBackend()
        backend.onChange = { [weak self] in self?.reloadAll() }
    }

    private func saveSettings() {
        let d = UserDefaults.standard
        d.set(settings.weekStartsOnMonday, forKey: Keys.weekMonday)
        d.set(settings.use24HourTime, forKey: Keys.use24h)
        d.set(settings.showTasksInCalendar, forKey: Keys.showTasks)
        d.set(settings.defaultEventMinutes, forKey: Keys.defaultLength)
        d.set(settings.defaultAlert.rawValue, forKey: Keys.defaultAlert)
    }

    // MARK: Loading

    func start() async {
        let result = await backend.requestAccess()
        access = (result.events || result.reminders) ? .granted : .denied
        reloadAll()
    }

    func reloadAll() {
        calendars = backend.calendars()
        reminderLists = backend.reminderLists()
        loadedRange = nil
        reloadEvents()
        Task { tasks = await backend.tasks() }
    }

    /// Loads events for a window around the selected date (three months each side).
    func reloadEvents(force: Bool = true) {
        let cal = calendar
        let anchor = selectedDate
        if !force, let r = loadedRange,
           let inner1 = cal.date(byAdding: .month, value: -2, to: anchor),
           let inner2 = cal.date(byAdding: .month, value: 2, to: anchor),
           r.contains(inner1), r.contains(inner2) { return }
        guard let from = cal.date(byAdding: .month, value: -3, to: anchor),
              let to = cal.date(byAdding: .month, value: 3, to: anchor) else { return }
        events = backend.events(from: from, to: to)
        loadedRange = from...to
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        reloadEvents(force: false)
    }

    // MARK: Lookups

    var visibleEvents: [CalEvent] {
        events.filter { !hiddenCalendarIDs.contains($0.calendarID) }
    }

    var visibleTasks: [TaskItem] {
        tasks.filter { !hiddenCalendarIDs.contains($0.listID) }
    }

    /// Tasks shown inside calendar views (respects the "show tasks" setting).
    var calendarTasks: [TaskItem] {
        settings.showTasksInCalendar ? visibleTasks : []
    }

    func info(for id: String) -> CalendarInfo? {
        calendars.first { $0.id == id } ?? reminderLists.first { $0.id == id }
    }

    func colorHex(for event: CalEvent) -> String {
        event.customColorHex ?? info(for: event.calendarID)?.colorHex ?? "#8e8e93"
    }

    func colorHex(for task: TaskItem) -> String {
        info(for: task.listID)?.colorHex ?? "#8e8e93"
    }

    var writableCalendars: [CalendarInfo] { calendars.filter(\.allowsModifications) }

    /// Matches a typed "#tag" to a calendar or list by name prefix.
    func match(tag: String?, in list: [CalendarInfo]) -> CalendarInfo? {
        guard let tag, !tag.isEmpty else { return nil }
        let aliases = ["gym": "fitness", "holiday": "holidays"]
        let t = aliases[tag] ?? tag
        return list.first { $0.title.lowercased() == t }
            ?? list.first { $0.title.lowercased().hasPrefix(t) }
            ?? list.first { $0.title.lowercased().contains(t) }
    }

    var defaultCalendarID: String? {
        writableCalendars.first(where: { $0.title.lowercased() == "personal" })?.id ?? writableCalendars.first?.id
    }

    var defaultListID: String? {
        reminderLists.first(where: { $0.title.lowercased() == "personal" })?.id ?? reminderLists.first?.id
    }

    // MARK: Navigation

    func goToday() {
        select(Date())
    }

    func shift(by value: Int) {
        let unit: Calendar.Component
        switch mode {
        case .day: unit = .day
        case .week: unit = .weekOfYear
        default: unit = .month
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            select(DateMath.shift(selectedDate, by: value, unit: unit, calendar: calendar))
        }
    }

    func openNew(at start: Date? = nil) {
        if mode == .tasks {
            sheet = .task(nil, defaultDue: nil)
            return
        }
        let cal = calendar
        let s = start ?? DateMath.nextRoundHour(on: selectedDate, now: now, calendar: cal)
        let e = cal.date(byAdding: .minute, value: settings.defaultEventMinutes, to: s) ?? s
        sheet = .newEvent(start: s, end: e, allDay: false)
    }

    // MARK: Changes (each shows an undo toast)

    func showToast(_ message: String, undo: (() -> Void)? = nil) {
        toast = UndoToast(message: message, undo: undo)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    private func perform(_ work: () throws -> Void) -> Bool {
        do { try work(); return true } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveEvent(_ event: CalEvent, isNew: Bool, previous: CalEvent?) {
        var saved: CalEvent?
        guard perform({ saved = try backend.save(event, isNew: isNew) }) else { return }
        reloadEvents()
        if isNew, let saved {
            showToast("Event added") { [weak self] in
                guard let self else { return }
                if let match = self.events.first(where: { $0.title == saved.title && $0.start == saved.start }) {
                    _ = self.perform { try self.backend.delete(match) }
                }
                self.reloadEvents()
            }
        } else if let previous, let saved {
            showToast("Event saved") { [weak self] in
                guard let self else { return }
                var restore = previous
                restore.id = saved.id
                _ = self.perform { try self.backend.save(restore, isNew: false) }
                self.reloadEvents()
            }
        }
    }

    func deleteEvent(_ event: CalEvent) {
        guard perform({ try backend.delete(event) }) else { return }
        reloadEvents()
        showToast("Event deleted") { [weak self] in
            guard let self else { return }
            var restored = event
            restored.repeatRule = .never // brings back this occurrence only
            _ = self.perform { try self.backend.save(restored, isNew: true) }
            self.reloadEvents()
        }
    }

    func toggle(_ task: TaskItem) {
        var t = task
        t.isCompleted.toggle()
        t.completionDate = t.isCompleted ? Date() : nil
        apply(task: t)
        showToast(t.isCompleted ? "Task completed" : "Task reopened") { [weak self] in
            self?.apply(task: task)
        }
    }

    private func apply(task: TaskItem) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            withAnimation(.easeInOut(duration: 0.2)) { tasks[i] = task }
        }
        _ = perform { try backend.save(task, isNew: false) }
    }

    func saveTask(_ task: TaskItem, isNew: Bool, previous: TaskItem?) {
        var saved: TaskItem?
        guard perform({ saved = try backend.save(task, isNew: isNew) }) else { return }
        Task { tasks = await backend.tasks() }
        showToast(isNew ? "Task added" : "Task saved") { [weak self] in
            guard let self, let saved else { return }
            if isNew {
                _ = self.perform { try self.backend.delete(saved) }
            } else if let previous {
                _ = self.perform { try self.backend.save(previous, isNew: false) }
            }
            Task { self.tasks = await self.backend.tasks() }
        }
    }

    func deleteTask(_ task: TaskItem) {
        guard perform({ try backend.delete(task) }) else { return }
        Task { tasks = await backend.tasks() }
        showToast("Task deleted") { [weak self] in
            guard let self else { return }
            _ = self.perform { try self.backend.save(task, isNew: true) }
            Task { self.tasks = await self.backend.tasks() }
        }
    }

    func setVisible(_ id: String, _ visible: Bool) {
        if visible { hiddenCalendarIDs.remove(id) } else { hiddenCalendarIDs.insert(id) }
    }

    func time(_ date: Date) -> String {
        DateText.time(date, use24h: settings.use24HourTime, calendar: calendar)
    }
}
