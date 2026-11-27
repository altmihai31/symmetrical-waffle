import Foundation

/// The arithmetic behind long-pressing the timeline to draw a new event.
public enum TimelineDraft {
    /// Rounds a minute of the day to the nearest `step`, inside 0...1440.
    public static func snap(_ minute: Double, step: Int = 15) -> Int {
        let s = Double(max(step, 1))
        let rounded = Int((minute / s).rounded()) * Int(s)
        return min(max(rounded, 0), 24 * 60)
    }

    /// Rounds down to the `step` the finger is in, so a press at 10:20 starts the draft at 10:15.
    public static func floorSnap(_ minute: Double, step: Int = 15) -> Int {
        let s = max(step, 1)
        let m = Int(minute.rounded(.down))
        return min(max((m / s) * s, 0), 24 * 60 - s)
    }

    /// The draft's start and end minutes. `anchor` is where the press began (already snapped);
    /// `current` is where the finger is now. Dragging up past the anchor flips the range,
    /// and the draft never gets shorter than `minLength`.
    public static func range(anchor: Int, current: Double, step: Int = 15, minLength: Int = 15,
                             defaultLength: Int = 60, moved: Bool) -> (start: Int, end: Int) {
        let day = 24 * 60
        guard moved else {
            let end = min(anchor + max(defaultLength, minLength), day)
            return (max(min(anchor, end - minLength), 0), end)
        }
        let c = snap(current, step: step)
        if c >= anchor {
            let end = min(max(c, anchor + minLength), day)
            return (min(anchor, end - minLength), end)
        } else {
            let start = max(min(c, anchor - minLength), 0)
            return (start, max(anchor, start + minLength))
        }
    }

    /// The date for a minute of `day`.
    public static func date(minute: Int, on day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minute, to: start) ?? start
    }
}

/// Whether ticking a task finishes everything due on its day.
public enum DayCompletion {
    /// True when `task` is open, has a due date, and every other task due that day is already done.
    public static func completesDay(_ task: TaskItem, among tasks: [TaskItem], calendar: Calendar) -> Bool {
        guard !task.isCompleted, let due = task.due else { return false }
        return tasks.allSatisfy { t in
            guard t.id != task.id, let d = t.due, calendar.isDate(d, inSameDayAs: due) else { return true }
            return t.isCompleted
        }
    }

    /// True when there are no open tasks due on or before `now`'s day (and at least one task exists).
    public static func allCaughtUp(_ tasks: [TaskItem], now: Date, calendar: Calendar) -> Bool {
        guard !tasks.isEmpty else { return false }
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return !tasks.contains { !$0.isCompleted && ($0.due.map { $0 < endOfToday } ?? false) }
    }
}
