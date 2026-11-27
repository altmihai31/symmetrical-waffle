import Foundation
import DaybookKit

enum AccessState: Equatable {
    case unknown
    case granted
    case denied
}

/// Where calendars, events and tasks come from. The app uses EventKit; UI tests and the
/// simulator screenshots use the in-memory demo backend (launch argument `-DaybookDemo YES`).
@MainActor
protocol CalendarBackend: AnyObject {
    func requestAccess() async -> (events: Bool, reminders: Bool)
    func calendars() -> [CalendarInfo]
    func reminderLists() -> [CalendarInfo]
    func events(from: Date, to: Date) -> [CalEvent]
    func tasks() async -> [TaskItem]
    /// Saves a new or changed event and returns it with its final id.
    @discardableResult func save(_ event: CalEvent, isNew: Bool) throws -> CalEvent
    func delete(_ event: CalEvent) throws
    @discardableResult func save(_ task: TaskItem, isNew: Bool) throws -> TaskItem
    func delete(_ task: TaskItem) throws
    var onChange: (() -> Void)? { get set }
}

enum BackendError: LocalizedError {
    case notFound
    case readOnlyCalendar

    var errorDescription: String? {
        switch self {
        case .notFound: return "That item no longer exists."
        case .readOnlyCalendar: return "This calendar can't be changed."
        }
    }
}
