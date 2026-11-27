import SwiftUI
import DaybookKit

/// One row in the List view and in search results.
struct AgendaRow: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let item: DayItem

    var body: some View {
        switch item {
        case .timed(let e), .allDay(let e):
            let c = ChipColors(hex: model.colorHex(for: e), scheme: scheme)
            // A tap gesture rather than a Button: a Button also fires at the end of a sideways swipe.
            Group {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 1) {
                        if e.isAllDay {
                            Text("all-day").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink2)
                        } else {
                            Text(model.time(e.start)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                            Text(model.time(e.end)).font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .frame(width: 52, alignment: .trailing)
                    RoundedRectangle(cornerRadius: 2).fill(c.base).frame(width: 4)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            EventGlyph(title: e.title, size: 13).foregroundStyle(c.text)
                            Text(e.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        if let loc = e.location, !loc.isEmpty {
                            Text(loc).font(.system(size: 13)).foregroundStyle(Theme.ink2)
                        } else if !e.isAllDay {
                            Text(DateText.duration(minutes: Int(e.end.timeIntervalSince(e.start) / 60)))
                                .font(.system(size: 13)).foregroundStyle(Theme.ink3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .onTapGesture { model.sheet = .event(e) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .rowSwipe(trailing: model.info(for: e.calendarID)?.allowsModifications == false ? nil :
                        SwipeAction(title: "Delete", icon: "trash", color: Theme.danger, removes: true) {
                            model.deleteEvent(e)
                        })
            .accessibilityIdentifier("row-\(e.title)")
        case .task(let t):
            TaskRow(task: t, showDue: false)
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject var model: AppModel
    let task: TaskItem
    var showDue: Bool = true

    var body: some View {
        let color = Color(hex: model.colorHex(for: task))
        let cal = model.calendar
        HStack(alignment: .center, spacing: 12) {
            if !showDue {
                Text(task.dueHasTime && task.due != nil ? model.time(task.due!) : "task")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.ink3)
                    .frame(width: 52, alignment: .trailing)
            }
            CheckBox(done: task.isCompleted, color: color, size: 20, round: true) { model.toggle(task) }
                .accessibilityIdentifier("check-\(task.title)")
            Group {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? Theme.ink3 : Theme.ink)
                    HStack(spacing: 6) {
                        if let list = model.info(for: task.listID) {
                            Circle().fill(color).frame(width: 7, height: 7)
                            Text(list.title).font(.system(size: 12)).foregroundStyle(Theme.ink2)
                        }
                        if showDue, let due = task.due {
                            let overdue = task.isOverdue(now: Date(), calendar: cal)
                            Text(dueText(due, cal: cal))
                                .font(.system(size: 12, weight: overdue ? .semibold : .regular))
                                .foregroundStyle(overdue ? Theme.danger : Theme.ink2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .onTapGesture { model.sheet = .task(task, defaultDue: nil) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
        .padding(.vertical, 7)
        .opacity(task.isCompleted ? 0.6 : 1)
        .rowSwipe(
            leading: SwipeAction(title: task.isCompleted ? "Not done" : "Done",
                                 icon: task.isCompleted ? "arrow.uturn.backward" : "checkmark",
                                 color: Color(hex: "#2fb35a")) { model.toggle(task) },
            trailing: task.isCompleted ? nil :
                SwipeAction(title: "Postpone", icon: "arrow.turn.up.right", color: Color(hex: "#ff9500")) {
                    model.postpone(task)
                })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task-\(task.title)")
    }

    private func dueText(_ due: Date, cal: Calendar) -> String {
        let day = DateText.dayHeader(due, now: Date(), calendar: cal)
        let short = ["Today", "Tomorrow", "Yesterday"].contains(day) ? day : DateText.shortDay(due, calendar: cal)
        return task.dueHasTime ? "\(short) · \(model.time(due))" : short
    }
}

struct AgendaView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let cal = model.calendar
        let sections = Agenda.sections(from: model.selectedDate, days: 60, events: model.visibleEvents,
                                       tasks: model.calendarTasks, includeTasks: true, now: Date(), calendar: cal)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if sections.isEmpty {
                    EmptyState(icon: "calendar", text: "Nothing planned in the next two months.")
                }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            AgendaRow(item: item).padding(.horizontal, 14)
                        }
                    } header: {
                        SectionHeader(title: section.title,
                                      subtitle: ["Today", "Tomorrow", "Yesterday"].contains(section.title)
                                        ? DateText.longDay(section.day, calendar: cal) : nil)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("listView")
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var count: Int? = nil
    var color: Color = Theme.ink

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.ink3) }
            Spacer()
            if let count { Text("\(count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink3) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.bg)
    }
}

/// A quiet message for an empty screen. The icon arrives with a small pop, then floats gently.
struct EmptyState: View {
    var icon: String = "calendar"
    let text: String
    var hint: String? = nil
    @State private var shown = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.ink3)
                .phaseAnimator([0.0, 1.0]) { image, phase in
                    image.offset(y: -4 * phase).opacity(0.75 + 0.25 * phase)
                } animation: { _ in .easeInOut(duration: 1.6) }
                .scaleEffect(shown ? 1 : 0.5)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink2)
            if let hint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 12)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .onAppear { withAnimation(Theme.Motion.bouncy.delay(0.1)) { shown = true } }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("emptyState")
    }
}

/// Shown at the top of Tasks when nothing is due today or overdue.
struct AllDoneBanner: View {
    @State private var shown = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color(hex: "#2fb35a"))
                .symbolEffect(.bounce, value: shown)
                .phaseAnimator([1.0, 1.06]) { image, s in
                    image.scaleEffect(s)
                } animation: { _ in .easeInOut(duration: 1.4) }
            VStack(alignment: .leading, spacing: 1) {
                Text("All done for today").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("Nothing due or overdue.").font(.system(size: 13)).foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#2fb35a").opacity(0.12)))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .scaleEffect(shown ? 1 : 0.9)
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(Theme.Motion.bouncy) { shown = true } }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("allDone")
    }
}

struct TasksView: View {
    @EnvironmentObject var model: AppModel
    @State private var showDone = false

    var body: some View {
        let groups = TaskGrouping.group(model.visibleTasks, now: Date(), calendar: model.calendar)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if groups.isEmpty {
                    EmptyState(icon: "checklist",
                               text: model.reminderLists.isEmpty && !model.isDemo
                               ? "No Reminders lists from iCloud, Google or Outlook yet."
                               : "No tasks. Tap + to add one.")
                } else if DayCompletion.allCaughtUp(model.visibleTasks, now: Date(), calendar: model.calendar) {
                    AllDoneBanner().transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    if g.group == .done {
                        Button {
                            withAnimation(Theme.Motion.snappy) { showDone.toggle() }
                        } label: {
                            HStack {
                                SectionHeader(title: "Done", count: g.tasks.count, color: Theme.ink2)
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(showDone ? 90 : 0))
                                    .foregroundStyle(Theme.ink3)
                                    .padding(.trailing, 16)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("doneGroup")
                        if showDone {
                            ForEach(g.tasks) { t in TaskRow(task: t).padding(.horizontal, 16) }
                        }
                    } else {
                        SectionHeader(title: g.group.rawValue, count: g.tasks.count,
                                      color: g.group == .overdue ? Theme.danger : Theme.ink)
                        ForEach(g.tasks) { t in TaskRow(task: t).padding(.horizontal, 16) }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tasksView")
    }
}

struct SearchResultsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let sections = Search.results(model.searchText, events: model.visibleEvents, tasks: model.visibleTasks,
                                      calendars: model.calendars + model.reminderLists, now: Date(),
                                      calendar: model.calendar)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if sections.isEmpty { EmptyState(icon: "magnifyingglass", text: "No matches for “\(model.searchText)”") }
                ForEach(sections) { section in
                    SectionHeader(title: section.title,
                                  subtitle: ["Today", "Tomorrow", "Yesterday"].contains(section.title)
                                    ? DateText.longDay(section.day, calendar: model.calendar, now: Date()) : nil)
                    ForEach(section.items) { item in AgendaRow(item: item).padding(.horizontal, 14) }
                }
            }
            .padding(.bottom, 40)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("searchResults")
    }
}

struct DrawerView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Daybook")
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    navRow("calendar", "Calendar") { model.mode = .month }
                    navRow("checklist", "Tasks") { model.mode = .tasks }
                    navRow("magnifyingglass", "Search") { model.searchOpen = true }
                    navRow("gearshape", "Calendars & settings") { model.sheet = .settings }
                    calendarSection(title: "Calendars", items: model.calendars)
                    calendarSection(title: "Reminders lists", items: model.reminderLists)
                    if model.isDemo {
                        Text("Demo data. Install on a phone to see your own calendars.")
                            .font(.footnote).foregroundStyle(Theme.ink3)
                            .padding(20)
                    }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sheet.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("drawer")
    }

    private func navRow(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.Motion.snappy) {
                model.drawerOpen = false
                action()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).frame(width: 24).foregroundStyle(Theme.accent)
                Text(title).font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("drawer-\(title)")
    }

    @ViewBuilder
    private func calendarSection(title: String, items: [CalendarInfo]) -> some View {
        if !items.isEmpty {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink3)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 6)
            ForEach(AccountKind.allCases, id: \.self) { acc in
                let group = items.filter { $0.account == acc }
                if !group.isEmpty {
                    Text(acc.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    ForEach(group) { c in
                        Toggle(isOn: Binding(get: { !model.hiddenCalendarIDs.contains(c.id) },
                                             set: { model.setVisible(c.id, $0) })) {
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                                Text(c.title).font(.system(size: 15))
                            }
                        }
                        .tint(Color(hex: c.colorHex))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("toggle-\(c.title)")
                    }
                }
            }
        }
    }
}
