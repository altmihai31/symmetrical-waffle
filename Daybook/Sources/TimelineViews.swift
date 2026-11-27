import SwiftUI
import DaybookKit

private let hourHeight: CGFloat = 52
private let gutter: CGFloat = 44

/// Hour lines, labels and timed event blocks for one or more day columns.
struct TimelineGrid: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let days: [Date]
    let events: [CalEvent]
    var tapToCreate: Bool = false
    @State private var nowTick = Date()

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
                        // Tap empty hour to create
                        if tapToCreate, let day = days.first {
                            ForEach(0..<24, id: \.self) { h in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .frame(width: colW, height: hourHeight)
                                    .offset(x: gutter, y: CGFloat(h) * hourHeight)
                                    .onTapGesture {
                                        model.openNew(at: cal.date(byAdding: .hour, value: h, to: cal.startOfDay(for: day)))
                                    }
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
                        // Scroll anchors (laid out, not offset, so scrollTo can find them)
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { h in
                                Color.clear.frame(width: 1, height: hourHeight).id("h\(h)")
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(height: hourHeight * 24 + 8)
                .padding(.top, 8)
            }
            .onAppear {
                let h = max(0, cal.component(.hour, from: Date()) - 1)
                proxy.scrollTo("h\(h)", anchor: .top)
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { nowTick = $0 }
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
                    Text(event.title)
                        .font(.system(size: compact ? 10.5 : 13, weight: .semibold))
                        .lineLimit(heightMinutes >= 45 ? 2 : 1)
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

    var body: some View {
        let cal = model.calendar
        let perDay: [[DayItem]] = days.map { day in
            DayContent.items(on: day, events: events.filter(\.isAllDay), tasks: tasks, includeTasks: true,
                             includeMultiDay: true, calendar: cal)
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

struct WeekView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let cal = model.calendar
        let days = DateMath.week(containing: model.selectedDate, calendar: cal)
        let symbols = DateMath.weekdaySymbols(calendar: cal)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: gutter, height: 1)
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    let today = cal.isDateInToday(day)
                    let selected = cal.isDate(day, inSameDayAs: model.selectedDate)
                    Button { withAnimation { model.select(day) } } label: {
                        VStack(spacing: 2) {
                            Text(symbols[i]).font(.system(size: 11, weight: .medium))
                                .foregroundStyle(today ? Theme.accent : Theme.ink2)
                            Text("\(cal.component(.day, from: day))")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(today || selected ? .white : Theme.ink)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(today ? Theme.accent : (selected ? Theme.ink3 : .clear)))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
            AllDayRow(days: days, events: model.visibleEvents, tasks: model.calendarTasks)
            TimelineGrid(days: days, events: model.visibleEvents)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(swipe)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weekView")
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30).onEnded { v in
            if abs(v.translation.width) > abs(v.translation.height) * 1.5, abs(v.translation.width) > 60 {
                model.shift(by: v.translation.width < 0 ? 1 : -1)
            }
        }
    }
}

struct DayView: View {
    @EnvironmentObject var model: AppModel

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
                    Button { withAnimation { model.select(day) } } label: {
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
            AllDayRow(days: [model.selectedDate], events: model.visibleEvents, tasks: model.calendarTasks)
            TimelineGrid(days: [model.selectedDate], events: model.visibleEvents, tapToCreate: true)
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
