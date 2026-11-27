import SwiftUI
import DaybookKit

private let hourHeight: CGFloat = 52
private let gutter: CGFloat = 44

/// A new event being drawn on the timeline with a long press, in minutes of the day.
struct TimelineDraftState: Equatable {
    var anchor: Int
    var start: Int
    var end: Int
    var located = false   // the finger's own position has replaced the hour it started in
}

/// Hour lines, labels and timed event blocks for one or more day columns.
/// In the Day view, a tap on empty time opens a new event at that hour, and a long press
/// drops in a draft you can drag to set its length.
struct TimelineGrid: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let days: [Date]
    let events: [CalEvent]
    var tasks: [TaskItem] = []
    var tapToCreate: Bool = false
    @State private var nowTick = Date()
    @State private var draft: TimelineDraftState?

    private static let space = "timeline"

    var body: some View {
        let cal = model.calendar
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                GeometryReader { geo in
                    let colW = (geo.size.width - gutter) / CGFloat(days.count)
                    ZStack(alignment: .topLeading) {
                        // Hour lines and labels
                        ForEach(0..<25, id: \.self) { h in
                            HStack(alignment: .center, spacing: 6) {
                                Text(h == 0 || h == 24 ? "" : DateText.time(minutes: h * 60, use24h: model.settings.use24HourTime))
                                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                                    .foregroundStyle(Theme.ink3)
                                    .opacity(labelHidden(h) ? 0 : 1)
                                    .frame(width: gutter - 8, alignment: .trailing)
                                Rectangle().fill(Theme.line).frame(height: 0.5)
                            }
                            .frame(height: 12)
                            .offset(y: CGFloat(h) * hourHeight - 6)
                        }
                        // Column separators
                        if days.count > 1 {
                            ForEach(1..<days.count, id: \.self) { i in
                                Rectangle().fill(Theme.line)
                                    .frame(width: 0.5, height: hourHeight * 24)
                                    .offset(x: gutter + CGFloat(i) * colW)
                            }
                        }
                        // Tap empty hour to create; long-press to draw a draft.
                        if tapToCreate, let day = days.first {
                            ForEach(0..<24, id: \.self) { h in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .frame(width: colW, height: hourHeight)
                                    .offset(x: gutter, y: CGFloat(h) * hourHeight)
                                    .onTapGesture {
                                        model.openNew(at: cal.date(byAdding: .hour, value: h, to: cal.startOfDay(for: day)))
                                    }
                                    .gesture(draftGesture(hour: h, day: day))
                                    .accessibilityIdentifier("hour-\(h)")
                            }
                        }
                        // Events
                        ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                            let slots = TimelineLayout.slots(for: day, events: events, calendar: cal)
                            let byID = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                            ForEach(slots, id: \.self) { slot in
                                if let ev = byID[slot.eventID] {
                                    let w = (colW - 3) / CGFloat(slot.columnCount)
                                    EventBlock(event: ev, compact: days.count > 1,
                                               heightMinutes: slot.endMinute - slot.startMinute)
                                        .frame(width: max(w - 1.5, 4),
                                               height: max(CGFloat(slot.endMinute - slot.startMinute) / 60 * hourHeight - 1.5, 14))
                                        .offset(x: gutter + CGFloat(idx) * colW + 1.5 + CGFloat(slot.column) * w,
                                                y: CGFloat(slot.startMinute) / 60 * hourHeight + 0.75)
                                }
                            }
                            // Tasks with a time sit on the timeline at that time.
                            ForEach(timedTasks(on: day, cal: cal)) { t in
                                let m = DateMath.minutesSinceStartOfDay(t.due!, calendar: cal)
                                TimelineTaskMarker(task: t, compact: days.count > 1)
                                    .frame(width: max(colW - 6, 4), height: 22)
                                    .offset(x: gutter + CGFloat(idx) * colW + 3,
                                            y: min(CGFloat(m) / 60 * hourHeight, hourHeight * 24 - 22))
                            }
                            // Now line on today's column
                            if cal.isDateInToday(day) {
                                let y = CGFloat(DateMath.minutesSinceStartOfDay(nowTick, calendar: cal)) / 60 * hourHeight
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.red).frame(width: colW, height: 1.5)
                                    Circle().fill(Color.red).frame(width: 8, height: 8).offset(x: -4)
                                }
                                .offset(x: gutter + CGFloat(idx) * colW, y: y - 0.75)
                                .allowsHitTesting(false)
                                .accessibilityIdentifier("nowLine")
                            }
                        }
                        // The draft being drawn, with its times on the hour rail.
                        if let draft {
                            DraftBlock(start: draft.start, end: draft.end)
                                .frame(width: colW - 6,
                                       height: CGFloat(draft.end - draft.start) / 60 * hourHeight - 1.5)
                                .offset(x: gutter + 3, y: CGFloat(draft.start) / 60 * hourHeight + 0.75)
                                .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
                                .allowsHitTesting(false)
                            railPill(draft.start).offset(y: CGFloat(draft.start) / 60 * hourHeight - 9)
                            railPill(draft.end).offset(y: CGFloat(draft.end) / 60 * hourHeight - 9)
                        }
                        // Scroll anchors (laid out, not offset, so scrollTo can find them)
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { h in
                                Color.clear.frame(width: 1, height: hourHeight).id("h\(h)")
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .coordinateSpace(.named(Self.space))
                }
                .frame(height: hourHeight * 24 + 8)
                .padding(.top, 8)
            }
            .scrollDisabled(draft != nil)
            .onAppear {
                let h = max(0, cal.component(.hour, from: Date()) - 1)
                proxy.scrollTo("h\(h)", anchor: .top)
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { nowTick = $0 }
    }

    private func timedTasks(on day: Date, cal: Calendar) -> [TaskItem] {
        tasks.filter { t in
            guard t.dueHasTime, let due = t.due else { return false }
            return cal.isDate(due, inSameDayAs: day)
        }
    }

    /// Hides an hour label while a draft's time pill covers it.
    private func labelHidden(_ h: Int) -> Bool {
        guard let draft else { return false }
        return abs(draft.start - h * 60) < 20 || abs(draft.end - h * 60) < 20
    }

    private func railPill(_ minute: Int) -> some View {
        Text(DateText.time(minutes: minute, use24h: model.settings.use24HourTime))
            .font(.system(size: 10.5, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(height: 18)
            .background(Capsule().fill(Theme.accent))
            .frame(width: gutter - 2, alignment: .trailing)
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    /// Long press (0.35 s) drops a one-hour draft at the hour; dragging then moves its end,
    /// snapping to 15 minutes with a tick each step. Letting go opens the new-event sheet.
    private func draftGesture(hour: Int, day: Date) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                var d: TimelineDraftState
                if let existing = draft {
                    d = existing
                } else {
                    Haptics.tap()
                    let r = TimelineDraft.range(anchor: hour * 60, current: 0,
                                                defaultLength: model.settings.defaultEventMinutes, moved: false)
                    d = TimelineDraftState(anchor: hour * 60, start: r.start, end: r.end)
                }
                if let drag {
                    if !d.located {
                        // Start where the finger actually is, not at the top of its hour.
                        d.anchor = TimelineDraft.floorSnap(Double(drag.startLocation.y / hourHeight) * 60)
                        d.located = true
                    }
                    let moved = abs(drag.translation.height) > hourHeight / 8
                    let r = TimelineDraft.range(anchor: d.anchor, current: Double(drag.location.y / hourHeight) * 60,
                                                defaultLength: model.settings.defaultEventMinutes, moved: moved)
                    d.start = r.start
                    d.end = r.end
                }
                if d != draft {
                    if let old = draft, old.start != d.start || old.end != d.end { Haptics.tick() }
                    withAnimation(draft == nil ? Theme.Motion.bouncy : Theme.Motion.quick) { draft = d }
                }
            }
            .onEnded { _ in
                guard let d = draft else { return }
                let cal = model.calendar
                model.sheet = .newEvent(start: TimelineDraft.date(minute: d.start, on: day, calendar: cal),
                                        end: TimelineDraft.date(minute: d.end, on: day, calendar: cal),
                                        allDay: false, drawn: true)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    withAnimation(Theme.Motion.snappy) { draft = nil }
                }
            }
    }
}

/// The lifted "No title" block shown while a new event is drawn on the timeline.
struct DraftBlock: View {
    @EnvironmentObject var model: AppModel
    let start: Int
    let end: Int

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Theme.accent).frame(width: 3.5)
            VStack(alignment: .leading, spacing: 1) {
                Text("No title").font(.system(size: 13, weight: .semibold))
                Text("\(DateText.time(minutes: start, use24h: model.settings.use24HourTime))–\(DateText.time(minutes: end, use24h: model.settings.use24HourTime)) · \(DateText.duration(minutes: end - start))")
                    .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                    .opacity(0.85)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.accent.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        .scaleEffect(1.03)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("draftBlock")
    }
}

/// A task with a due time, drawn on the timeline as a slim row with its checkbox.
struct TimelineTaskMarker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let task: TaskItem
    var compact = false

    var body: some View {
        let c = ChipColors(hex: model.colorHex(for: task), scheme: scheme)
        HStack(spacing: 5) {
            CheckBox(done: task.isCompleted, color: c.base, size: compact ? 12 : 15, round: true) { model.toggle(task) }
                .accessibilityIdentifier("check-\(task.title)")
            Text(task.title)
                .font(.system(size: compact ? 10 : 12.5, weight: .semibold))
                .strikethrough(task.isCompleted)
                .foregroundStyle(c.text)
                .lineLimit(1)
                .onTapGesture { model.sheet = .task(task, defaultDue: nil) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .frame(maxHeight: .infinity)
        .background(Capsule().fill(c.fill))
        .background(Capsule().fill(Theme.bg))
        .overlay(Capsule().stroke(c.base.opacity(0.7), lineWidth: 1))
        .opacity(task.isCompleted ? 0.6 : 1)
        .liftable("task:\(task.id)", title: task.title, color: c.base, model: model)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("marker-\(task.title)")
    }
}

struct EventBlock: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let event: CalEvent
    let compact: Bool
    let heightMinutes: Int

    var body: some View {
        let c = ChipColors(hex: model.colorHex(for: event), scheme: scheme)
        Button { model.sheet = .event(event) } label: {
            HStack(spacing: 0) {
                Rectangle().fill(c.base).frame(width: 3.5)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if !compact { EventGlyph(title: event.title, size: 11.5) }
                        Text(event.title)
                            .font(.system(size: compact ? 10.5 : 13, weight: .semibold))
                            .lineLimit(heightMinutes >= 45 ? 2 : 1)
                    }
                    if heightMinutes >= 45 {
                        Text(subtitle)
                            .font(.system(size: compact ? 9.5 : 11.5, weight: .medium))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(c.text)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(c.fill)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .liftable("event:\(event.id)", title: event.title, color: c.base, model: model)
        .accessibilityIdentifier("block-\(event.title)")
    }

    private var subtitle: String {
        let t = "\(model.time(event.start))–\(model.time(event.end))"
        if let loc = event.location, !loc.isEmpty, !compact { return "\(t) · \(loc)" }
        return compact ? (event.location ?? t) : t
    }
}

/// All-day events (including multi-day ones) and, optionally, tasks above the timeline.
struct AllDayRow: View {
    @EnvironmentObject var model: AppModel
    let days: [Date]
    let events: [CalEvent]
    let tasks: [TaskItem]
    /// The timeline below draws tasks that have a time, so leave them out here.
    var timedTasksOnTimeline = false

    var body: some View {
        let cal = model.calendar
        let perDay: [[DayItem]] = days.map { day in
            DayContent.items(on: day, events: events.filter(\.isAllDay),
                             tasks: timedTasksOnTimeline ? tasks.filter { !$0.dueHasTime } : tasks,
                             includeTasks: true, includeMultiDay: true, calendar: cal)
        }
        let maxCount = perDay.map(\.count).max() ?? 0
        let limit = days.count > 1 ? 3 : 6
        if maxCount > 0 {
            HStack(alignment: .top, spacing: 0) {
                Text("all-day")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: gutter - 4, alignment: .trailing)
                    .padding(.trailing, 4)
                    .padding(.top, 3)
                HStack(alignment: .top, spacing: 2) {
                    ForEach(Array(perDay.enumerated()), id: \.offset) { _, items in
                        VStack(spacing: 2) {
                            ForEach(Array(items.prefix(limit))) { item in
                                EntryChip(item: item, height: days.count > 1 ? 15 : 22,
                                          fontSize: days.count > 1 ? 10 : 13)
                            }
                            if items.count > limit {
                                Text("+\(items.count - limit)").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Theme.ink3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 5)
            .padding(.trailing, 4)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        }
    }
}

/// Seven days from the selected date as rows, each with its entries as tiles side by side.
struct WeekView: View {
    @EnvironmentObject var model: AppModel
    private let labelWidth: CGFloat = 54
    private let tileWidth: CGFloat = 72

    var body: some View {
        let cal = model.calendar
        let days = DateMath.days(from: model.selectedDate, count: 7, calendar: cal)
        let events = model.visibleEvents
        let tasks = model.calendarTasks
        GeometryReader { geo in
            let rowH = geo.size.height / 7
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let items = DayContent.items(on: day, events: events, tasks: tasks, includeTasks: true,
                                                 includeMultiDay: true, calendar: cal)
                    WeekRow(day: day, items: items, height: rowH, labelWidth: labelWidth, tileWidth: tileWidth, index: index)
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { v in
                if abs(v.translation.height) > abs(v.translation.width) * 1.5, abs(v.translation.height) > 80 {
                    let next = v.translation.height < 0
                    model.shift(by: next ? 1 : -1, edge: next ? .bottom : .top)
                }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weekView")
    }
}

/// One day of the week view; entries can be dropped on it to move them to this day.
struct WeekRow: View {
    @EnvironmentObject var model: AppModel
    let day: Date
    let items: [DayItem]
    let height: CGFloat
    let labelWidth: CGFloat
    let tileWidth: CGFloat
    var index = 0
    @State private var dropTargeted = false

    var body: some View {
        let cal = model.calendar
        let today = cal.isDateInToday(day)
        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let weekday = symbols[cal.component(.weekday, from: day) - 1]
        let weekend = [1, 7].contains(cal.component(.weekday, from: day))
        return HStack(spacing: 0) {
            Button {
                model.navigate(.zoom(UnitPoint(x: 0.08, y: (CGFloat(index) + 0.5) / 7))) { model.select(day); model.mode = .day }
            } label: {
                VStack(spacing: 0) {
                    Text(weekday).font(.system(size: 14))
                    Text("\(cal.component(.day, from: day))").font(.system(size: 19, weight: .medium))
                }
                .foregroundStyle(today ? Theme.accent : (weekend ? Theme.ink2 : Theme.ink))
                .frame(width: labelWidth, height: height)
                .overlay(alignment: .leading) {
                    if today { Rectangle().fill(Theme.accent).frame(width: 4) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("weekday-\(DayCell.key(day, cal))")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(items) { item in
                        WeekTile(item: item).frame(width: tileWidth, height: height - 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                let cal = model.calendar
                model.openNew(at: DateMath.nextRoundHour(on: day, now: Date(), calendar: cal))
            }
        }
        .frame(height: height)
        .background(dropTargeted ? Theme.accentSoft : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        .overlay {
            if dropTargeted {
                Rectangle().stroke(Theme.accent, lineWidth: 2)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .scaleEffect(dropTargeted ? 1.02 : 1)
        .zIndex(dropTargeted ? 1 : 0)
        .animation(Theme.Motion.bouncy, value: dropTargeted)
        .dropDestination(for: String.self) { payloads, _ in
            model.drop(payloads, on: day)
        } isTargeted: { on in
            dropTargeted = on
            if on { Haptics.tick() }
        }
    }
}

struct WeekTile: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let item: DayItem

    var body: some View {
        switch item {
        case .allDay(let e), .timed(let e):
            let c = ChipColors(hex: model.colorHex(for: e), scheme: scheme)
            Button { model.sheet = .event(e) } label: {
                tile(color: c, fill: c.fill.opacity(scheme == .dark ? 0.75 : 1)) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        EventGlyph(title: e.title, size: 11)
                        Text(e.title).font(.system(size: 12.5)).lineLimit(3)
                    }
                    .foregroundStyle(c.text)
                    Spacer(minLength: 0)
                    Group {
                        if e.isAllDay {
                            Text("all-day")
                        } else {
                            Text(model.time(e.start))
                            Text(DateText.duration(minutes: Int(e.end.timeIntervalSince(e.start) / 60)))
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(c.text.opacity(0.85))
                }
            }
            .buttonStyle(.plain)
            .liftable("event:\(e.id)", title: e.title, color: c.base, model: model)
            .accessibilityIdentifier("tile-\(e.title)")
        case .task(let t):
            let c = ChipColors(hex: model.colorHex(for: t), scheme: scheme)
            tile(color: c, fill: Theme.tile) {
                CheckBox(done: t.isCompleted, color: c.base, size: 18) { model.toggle(t) }
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("check-\(t.title)")
                Button { model.sheet = .task(t, defaultDue: nil) } label: {
                    Text(t.title).font(.system(size: 12.5)).foregroundStyle(c.text)
                        .strikethrough(t.isCompleted)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .buttonStyle(.plain)
            }
            .opacity(t.isCompleted ? 0.55 : 1)
            .liftable("task:\(t.id)", title: t.title, color: c.base, model: model)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tile-\(t.title)")
        }
    }

    private func tile<C: View>(color: ChipColors, fill: Color, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(color.base).frame(height: 4)
            VStack(alignment: .leading, spacing: 1) { content() }
                .padding(.horizontal, 5)
                .padding(.top, 5)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(fill)
    }
}

/// Strip of seven-day blocks at the bottom of the week view, e.g. "Nov-Dec / 27-3".
struct WeekStrip: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let cal = model.calendar
        let starts = (-10...10).compactMap { cal.date(byAdding: .day, value: $0 * 7, to: model.selectedDate) }
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(starts, id: \.self) { start in
                        let label = DateText.weekStripLabel(start, calendar: cal)
                        let shown = cal.isDate(start, inSameDayAs: model.selectedDate)
                        let span = cal.startOfDay(for: start)...(cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: start)) ?? start)
                        let holdsToday = span.contains(Date()) && !shown
                        Button {
                            model.go(to: start)
                        } label: {
                            VStack(spacing: 0) {
                                Text(label.months).font(.system(size: 13))
                                Text(label.days).font(.system(size: 19, weight: .medium))
                            }
                            .foregroundStyle(shown ? .white : (holdsToday ? Theme.accent : Theme.ink2))
                            .frame(width: 70, height: 46)
                            .background(Capsule().fill(shown ? Theme.accent : .clear))
                            .overlay(Capsule().stroke(holdsToday ? Theme.accent : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .id(start)
                    }
                }
                .padding(.horizontal, 6)
            }
            .onAppear { proxy.scrollTo(starts[10], anchor: .center) }
            .onChange(of: model.selectedDate) { _, new in
                withAnimation(Theme.Motion.snappy) { proxy.scrollTo(new, anchor: .center) }
            }
        }
        .frame(height: 56)
        .padding(.bottom, 24)
        .background(Theme.chrome)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        .accessibilityIdentifier("weekStrip")
    }
}

struct DayView: View {
    @EnvironmentObject var model: AppModel

    private var dayIsEmpty: Bool {
        DayContent.items(on: model.selectedDate, events: model.visibleEvents, tasks: model.calendarTasks,
                         includeTasks: true, includeMultiDay: true, calendar: model.calendar).isEmpty
    }

    var body: some View {
        let cal = model.calendar
        let week = DateMath.week(containing: model.selectedDate, calendar: cal)
        let symbols = DateMath.weekdaySymbols(calendar: cal)
        VStack(spacing: 0) {
            // Week strip
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, day in
                    let today = cal.isDateInToday(day)
                    let selected = cal.isDate(day, inSameDayAs: model.selectedDate)
                    Button { model.go(to: day) } label: {
                        VStack(spacing: 3) {
                            Text(symbols[i]).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.ink2)
                            Text("\(cal.component(.day, from: day))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(selected ? .white : (today ? Theme.accent : Theme.ink))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(selected ? Theme.accent : .clear))
                                .overlay(Circle().stroke(today && !selected ? Theme.accent : .clear, lineWidth: 1.5))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("strip-\(DayCell.key(day, cal))")
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            Text(DateText.longDay(model.selectedDate, calendar: cal, now: Date()))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            AllDayRow(days: [model.selectedDate], events: model.visibleEvents, tasks: model.calendarTasks,
                      timedTasksOnTimeline: true)
            TimelineGrid(days: [model.selectedDate], events: model.visibleEvents, tasks: model.calendarTasks,
                         tapToCreate: true)
                .overlay(alignment: .top) {
                    if dayIsEmpty {
                        EmptyState(icon: "hand.tap", text: "Nothing planned",
                                   hint: "Touch and hold the timeline to add an event, then drag to set its length.")
                            .padding(.top, 36)
                            .allowsHitTesting(false)
                    }
                }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { v in
                if abs(v.translation.width) > abs(v.translation.height) * 1.5, abs(v.translation.width) > 60 {
                    model.shift(by: v.translation.width < 0 ? 1 : -1)
                }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayView")
    }
}
