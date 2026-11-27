import Foundation

/// Date arithmetic for drag-to-reschedule and postponing tasks.
public enum Reschedule {
    /// Moves an event so it starts on `day`, keeping its time of day and length.
    public static func move(start: Date, end: Date, toDay day: Date, calendar cal: Calendar) -> (start: Date, end: Date) {
        let from = cal.startOfDay(for: start)
        let to = cal.startOfDay(for: day)
        let days = cal.dateComponents([.day], from: from, to: to).day ?? 0
        guard days != 0 else { return (start, end) }
        let s = cal.date(byAdding: .day, value: days, to: start) ?? start
        let e = cal.date(byAdding: .day, value: days, to: end) ?? end
        return (s, e)
    }

    /// Moves a task's due date to `day`, keeping its time if it has one.
    public static func move(due: Date?, toDay day: Date, calendar cal: Calendar) -> Date {
        guard let due else { return cal.startOfDay(for: day) }
        return move(start: due, end: due, toDay: day, calendar: cal).start
    }

    /// The due date after "postpone": tomorrow, or the day after the current due date if that is later.
    /// A due time is kept.
    public static func postponed(due: Date?, now: Date, calendar cal: Calendar) -> Date {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        guard let due else { return tomorrow }
        let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: due)) ?? tomorrow
        let day = max(next, tomorrow)
        return move(due: due, toDay: day, calendar: cal)
    }
}
