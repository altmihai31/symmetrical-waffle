import SwiftUI
import DaybookKit

struct MonthView: View {
    @EnvironmentObject var model: AppModel

    private let headerHeight: CGFloat = 22
    private let dateRow: CGFloat = 19
    private let line: CGFloat = 17   // chip height + spacing
    private let chip: CGFloat = 15

    var body: some View {
        let cal = model.calendar
        let grid = MonthGrid(containing: model.selectedDate, calendar: cal)
        let events = model.visibleEvents
        let tasks = model.calendarTasks
        let symbols = DateMath.weekdaySymbols(calendar: cal)
        let todayWeekdayIndex = (cal.component(.weekday, from: Date()) - cal.firstWeekday + 7) % 7

        GeometryReader { geo in
            let colW = geo.size.width / 7
            let rowH = (geo.size.height - headerHeight) / CGFloat(max(grid.weeks.count, 1))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(symbols[i])
                            .font(.system(size: 12, weight: i == todayWeekdayIndex ? .bold : .medium))
                            .foregroundStyle(i == todayWeekdayIndex ? Theme.accent : Theme.ink2)
                            .frame(width: colW, height: headerHeight)
                    }
                }
                ForEach(grid.weeks, id: \.self) { week in
                    weekRow(week, grid: grid, events: events, tasks: tasks, colW: colW, rowH: rowH, cal: cal)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 25)
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if abs(dx) > abs(dy), abs(dx) > 50 { model.shift(by: dx < 0 ? 1 : -1) }
                    else if abs(dy) > abs(dx), abs(dy) > 60 { model.shift(by: dy < 0 ? 1 : -1) }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthView")
    }

    private func weekRow(_ week: [Date], grid: MonthGrid, events: [CalEvent], tasks: [TaskItem],
                         colW: CGFloat, rowH: CGFloat, cal: Calendar) -> some View {
        let segments = MonthLayout.barSegments(week: week, events: events, calendar: cal)
        let reserved = MonthLayout.reservedLanes(for: segments)
        let byID = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let selectedWeek = week.contains { cal.isDate($0, inSameDayAs: model.selectedDate) }

        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { col, day in
                    let items = DayContent.items(on: day, events: events, tasks: tasks, includeTasks: true, calendar: cal)
                    DayCell(day: day, items: items, reservedLines: reserved[col],
                            inMonth: grid.isInMonth(day, calendar: cal), selectedWeek: selectedWeek,
                            width: colW, height: rowH, dateRow: dateRow, line: line, chip: chip)
                }
            }
            ForEach(segments, id: \.self) { seg in
                if let ev = byID[seg.eventID],
                   CGFloat(seg.lane + 1) * line + dateRow <= rowH {
                    MultiDayBar(event: ev, segment: seg, height: chip)
                        .frame(width: CGFloat(seg.endColumn - seg.startColumn + 1) * colW - 3)
                        .offset(x: CGFloat(seg.startColumn) * colW + 1.5, y: dateRow + CGFloat(seg.lane) * line)
                }
            }
        }
        .frame(height: rowH)
    }
}

struct DayCell: View {
    @EnvironmentObject var model: AppModel
    let day: Date
    let items: [DayItem]
    let reservedLines: Int
    let inMonth: Bool
    let selectedWeek: Bool
    let width: CGFloat
    let height: CGFloat
    let dateRow: CGFloat
    let line: CGFloat
    let chip: CGFloat

    var body: some View {
        let cal = model.calendar
        let isToday = cal.isDateInToday(day)
        let isSelected = cal.isDate(day, inSameDayAs: model.selectedDate)
        let capacity = max(0, Int((height - dateRow - CGFloat(reservedLines) * line - 2) / line))
        let overflow = items.count > capacity
        let shown = overflow ? Array(items.prefix(max(0, capacity - 1))) : items
        let hidden = items.count - shown.count

        VStack(alignment: .leading, spacing: line - chip) {
            HStack(spacing: 2) {
                if isSelected && hidden > 0 {
                    Text("+\(hidden)").font(.system(size: 10.5, weight: .bold)).foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 12.5, weight: isToday || isSelected ? .bold : .semibold))
                    .foregroundStyle(numberColor(isToday: isToday, isSelected: isSelected))
                    .padding(.horizontal, isToday && !isSelected ? 5 : 0)
                    .background {
                        if isToday && !isSelected { Capsule().fill(Theme.accent) }
                    }
            }
            .padding(.horizontal, 4)
            .frame(height: dateRow - 2)
            .background(isSelected ? Theme.accent : .clear)

            if reservedLines > 0 {
                Color.clear.frame(height: CGFloat(reservedLines) * line - (line - chip))
            }
            ForEach(shown) { item in
                EntryChip(item: item, height: chip)
                    .padding(.horizontal, 1.5)
            }
            if hidden > 0 && !isSelected {
                Text("+\(hidden)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .padding(.leading, 4)
                    .frame(height: chip)
            }
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height, alignment: .top)
        .background(background(isSelected: isSelected))
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                withAnimation(.easeInOut(duration: 0.2)) { model.mode = .day }
            } else {
                withAnimation(.easeInOut(duration: 0.15)) { model.select(day) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-\(Self.key(day, cal))")
    }

    private func numberColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected || isToday { return .white }
        return inMonth ? Theme.ink : Theme.ink3
    }

    private func background(isSelected: Bool) -> Color {
        if !inMonth { return Theme.outsideMonth }
        if selectedWeek { return Theme.accentSoft.opacity(0.45) }
        return .clear
    }

    static func key(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
