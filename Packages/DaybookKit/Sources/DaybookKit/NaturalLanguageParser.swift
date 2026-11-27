import Foundation

/// What the parser recognised in a typed title, e.g.
/// "Lunch with Ana tomorrow 1pm at Origo #personal".
public struct ParsedInput: Equatable, Sendable {
    public enum TokenKind: String, Sendable {
        case calendar, allDay, duration, time, date, location
    }

    public struct Token: Equatable, Sendable {
        public let kind: TokenKind
        /// UTF-16 range in the original text.
        public let range: NSRange
        public let text: String
    }

    public var title: String = ""
    public var date: Date?
    public var startMinute: Int?
    public var endMinute: Int?
    public var durationMinutes: Int?
    public var isAllDay: Bool = false
    public var calendarTag: String?
    public var location: String?
    public var tokens: [Token] = []

    public init() {}

    public var recognisedAnything: Bool { !tokens.isEmpty }
}

/// The start, end and all-day flag after defaults are applied.
public struct ResolvedTiming: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
}

public struct NaturalLanguageParser: Sendable {
    public var calendar: Calendar
    public var now: Date

    public init(calendar: Calendar, now: Date = Date()) {
        self.calendar = calendar
        self.now = now
    }

    private static let monthIndex: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
    ]
    private static let weekdayIndex: [String: Int] = [
        "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7
    ]
    private static let monthPattern = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)(?:uary|ruary|ch|il|e|y|ust|tember|t|ober|ember)?\\.?"

    public func parse(_ text: String) -> ParsedInput {
        var out = ParsedInput()
        // Work on a padded copy; every match is blanked with spaces of the same length,
        // so ranges in `work` are the original ranges shifted by one.
        let work = NSMutableString(string: " " + text + " ")
        let today = calendar.startOfDay(for: now)

        func take(_ pattern: String, _ kind: ParsedInput.TokenKind, caseInsensitive: Bool = true,
                  tokenGroup: Int? = nil,
                  _ handle: ([String?]) -> Bool) {
            let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
            guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            let snapshot = String(work)
            let ns = snapshot as NSString
            for m in re.matches(in: snapshot, range: NSRange(location: 0, length: ns.length)) {
                var groups: [String?] = []
                for i in 0..<m.numberOfRanges {
                    let r = m.range(at: i)
                    groups.append(r.location == NSNotFound ? nil : ns.substring(with: r))
                }
                guard handle(groups) else { continue }
                var r = m.range(at: tokenGroup ?? 0)
                // Trim the leading whitespace that patterns consume.
                while r.length > 0, let ch = Unicode.Scalar(ns.character(at: r.location)),
                      CharacterSet.whitespaces.contains(ch) {
                    r.location += 1; r.length -= 1
                }
                let blankRange = m.range(at: 0)
                work.replaceCharacters(in: blankRange, with: String(repeating: " ", count: blankRange.length))
                let original = NSRange(location: r.location - 1, length: r.length)
                out.tokens.append(.init(kind: kind, range: original, text: ns.substring(with: r)))
                return // one match per call, like the mockup
            }
        }

        func hm(_ h: String?, _ m: String?, _ ap: String?) -> Int {
            var hour = Int(h ?? "0") ?? 0
            let minute = Int(m ?? "0") ?? 0
            if let ap = ap?.lowercased() {
                if ap == "pm" && hour < 12 { hour += 12 }
                if ap == "am" && hour == 12 { hour = 0 }
            }
            return hour * 60 + minute
        }

        // #calendar
        take("\\s#([\\p{L}\\p{N}_-]+)", .calendar) { g in
            out.calendarTag = g[1]?.lowercased(); return true
        }
        // all day
        take("\\s(all[ -]day)\\b", .allDay) { _ in out.isAllDay = true; return true }
        // for 90 min, 2h, 90m
        take("\\s(?:for\\s+)?(\\d+(?:[.,]\\d+)?)\\s*(h|hrs?|hours?|m|mins?|minutes?)(?=\\s)", .duration) { g in
            let n = Double((g[1] ?? "0").replacingOccurrences(of: ",", with: ".")) ?? 0
            let unit = (g[2] ?? "m").lowercased()
            out.durationMinutes = Int((n * (unit.hasPrefix("h") ? 60 : 1)).rounded())
            return out.durationMinutes! > 0
        }
        // 10-11, 9:30–11, 2pm to 4pm
        take("\\s(?:at\\s+|from\\s+)?(\\d{1,2})(?:[:.](\\d{2}))?\\s*(am|pm)?\\s*(?:-|–|—|to)\\s*(\\d{1,2})(?:[:.](\\d{2}))?\\s*(am|pm)?(?=\\s)", .time) { g in
            guard let h1 = Int(g[1] ?? ""), let h2 = Int(g[4] ?? ""), h1 <= 23, h2 <= 23 else { return false }
            let a2 = g[6]
            let a1 = g[3] ?? ((a2 != nil && h1 <= h2) ? a2 : nil)
            let s = hm(g[1], g[2], a1)
            var e = hm(g[4], g[5], a2)
            if e <= s { e += 12 * 60 }
            if e > 24 * 60 { e = s + 60 }
            out.startMinute = s; out.endMinute = e
            return true
        }
        // 3pm, at 7 am
        if out.startMinute == nil {
            take("\\s(?:at\\s+)?(\\d{1,2})(?:[:.](\\d{2}))?\\s*(am|pm)(?=\\s)", .time) { g in
                guard let h = Int(g[1] ?? ""), h <= 12 else { return false }
                out.startMinute = hm(g[1], g[2], g[3]); return true
            }
        }
        // at 6 (bare hours before 8 mean the evening), at 18:30
        if out.startMinute == nil {
            take("\\s(?:at\\s+)(\\d{1,2})(?:[:.](\\d{2}))?(?=\\s)", .time) { g in
                guard let h = Int(g[1] ?? ""), h <= 23 else { return false }
                out.startMinute = hm(g[1], g[2], h < 8 ? "pm" : nil); return true
            }
        }
        // 18:30
        if out.startMinute == nil {
            take("\\s(\\d{1,2})[:.](\\d{2})(?=\\s)", .time) { g in
                guard let h = Int(g[1] ?? ""), h <= 23, let m = Int(g[2] ?? ""), m < 60 else { return false }
                out.startMinute = hm(g[1], g[2], nil); return true
            }
        }
        // today / tonight
        take("\\s(?:on\\s+)?(today|tonight)\\b", .date) { g in
            out.date = today
            if g[1]?.lowercased() == "tonight" && out.startMinute == nil { out.startMinute = 20 * 60 }
            return true
        }
        if out.date == nil {
            take("\\s(?:on\\s+)?(tomorrow|tmrw)\\b", .date) { _ in
                out.date = calendar.date(byAdding: .day, value: 1, to: today); return true
            }
        }
        if out.date == nil {
            take("\\s(?:on\\s+)?(next\\s+week)\\b", .date) { _ in
                let weekStart = DateMath.week(containing: today, calendar: calendar).first ?? today
                out.date = calendar.date(byAdding: .day, value: 7, to: weekStart); return true
            }
        }
        if out.date == nil {
            take("\\s(?:on\\s+)?(next\\s+)?(sun|mon|tue|wed|thu|fri|sat)(?:day|sday|nesday|rsday|urday|s|r|rs)?\\b", .date) { g in
                guard let key = g[2]?.lowercased(), let target = Self.weekdayIndex[key] else { return false }
                let current = calendar.component(.weekday, from: today)
                var diff = (target - current + 7) % 7
                if diff == 0 { diff = 7 }
                if g[1] != nil && diff < 7 { diff += 7 }
                out.date = calendar.date(byAdding: .day, value: diff, to: today)
                return true
            }
        }
        if out.date == nil {
            take("\\s(?:on\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+" + Self.monthPattern + "(?=[\\s,])", .date) { g in
                guard let d = Int(g[1] ?? ""), let mo = Self.monthIndex[(g[2] ?? "").lowercased()] else { return false }
                out.date = dateFor(day: d, month: mo, today: today)
                return out.date != nil
            }
        }
        if out.date == nil {
            take("\\s(?:on\\s+)?" + Self.monthPattern + "\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b", .date) { g in
                guard let mo = Self.monthIndex[(g[1] ?? "").lowercased()], let d = Int(g[2] ?? "") else { return false }
                out.date = dateFor(day: d, month: mo, today: today)
                return out.date != nil
            }
        }
        // at Capitalised Place (up to four words)
        take("\\s(?:[Aa]t|@)\\s+([\\p{Lu}\\p{N}][^\\s#]*(?:\\s+\\p{Lu}[^\\s#]*){0,3})(?=\\s)", .location,
             caseInsensitive: false, tokenGroup: 0) { g in
            out.location = g[1]; return true
        }

        if out.isAllDay { out.startMinute = nil; out.endMinute = nil }
        if let s = out.startMinute, out.endMinute == nil, let d = out.durationMinutes {
            out.endMinute = s + d
        }

        var title = String(work)
        if let re = try? NSRegularExpression(pattern: "\\s+(at|on|from|for|by)\\s*$", options: [.caseInsensitive]) {
            title = re.stringByReplacingMatches(in: title, range: NSRange(location: 0, length: (title as NSString).length), withTemplate: "")
        }
        title = title.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        out.title = title
        out.tokens.sort { $0.range.location < $1.range.location }
        return out
    }

    private func dateFor(day: Int, month: Int, today: Date) -> Date? {
        let year = calendar.component(.year, from: today)
        var comps = DateComponents(year: year, month: month, day: day)
        guard var date = calendar.date(from: comps),
              calendar.component(.day, from: date) == day else { return nil }
        if date < today {
            comps.year = year + 1
            date = calendar.date(from: comps) ?? date
        }
        return date
    }

    /// Applies defaults: the selected day, the next round hour and the default length.
    public func resolve(_ p: ParsedInput, selectedDay: Date, defaultMinutes: Int = 60) -> ResolvedTiming {
        let day = calendar.startOfDay(for: p.date ?? selectedDay)
        if p.isAllDay {
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return ResolvedTiming(start: day, end: end, isAllDay: true)
        }
        let defaultStart = DateMath.nextRoundHour(on: day, now: now, calendar: calendar)
        let startMinute = p.startMinute ?? DateMath.minutesSinceStartOfDay(defaultStart, calendar: calendar)
        let endMinute = p.endMinute ?? (startMinute + (p.durationMinutes ?? defaultMinutes))
        let start = calendar.date(byAdding: .minute, value: startMinute, to: day) ?? day
        let end = calendar.date(byAdding: .minute, value: endMinute, to: day) ?? start
        return ResolvedTiming(start: start, end: end, isAllDay: false)
    }
}
