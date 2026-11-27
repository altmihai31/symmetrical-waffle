import SwiftUI
import DaybookKit

struct TaskEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let original: TaskItem?
    @State private var draft: TaskItem
    @State private var hasDue: Bool
    @State private var showDateWheel = false
    @State private var showTimeWheel = false
    @State private var confirmDelete = false
    @FocusState private var titleFocused: Bool

    init(original: TaskItem?, defaultDue: Date?) {
        self.original = original
        let t = original ?? TaskItem(id: "", title: "", listID: "", due: defaultDue)
        _draft = State(initialValue: t)
        _hasDue = State(initialValue: t.due != nil)
    }

    private var cal: Calendar { model.calendar }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: original == nil ? "New Task" : "Edit Task", pill: "Save",
                        pillEnabled: !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && !draft.listID.isEmpty,
                        close: { dismiss() }, action: save)
            ScrollView {
                VStack(spacing: 14) {
                    Card {
                        HStack(spacing: 10) {
                            CheckBox(done: draft.isCompleted, color: Color(hex: model.colorHex(for: draft)), size: 20, round: true) {
                                draft.isCompleted.toggle()
                            }
                            TextField(original == nil ? "Renew passport by next Friday" : "Title", text: $draft.title, axis: .vertical)
                                .font(.system(size: 19, weight: .semibold))
                                .focused($titleFocused)
                                .accessibilityIdentifier("taskTitleField")
                        }
                        .padding(14)
                    }
                    Card {
                        CardRow(icon: "calendar", title: "Due date") {
                            Toggle("", isOn: Binding(get: { hasDue }, set: { on in
                                withAnimation {
                                    hasDue = on
                                    draft.due = on ? (draft.due ?? model.selectedDate) : nil
                                    if !on { draft.dueHasTime = false; showDateWheel = false; showTimeWheel = false }
                                }
                            })).labelsHidden()
                        }
                        if hasDue, let due = draft.due {
                            Button { withAnimation { showDateWheel.toggle(); showTimeWheel = false } } label: {
                                Text(DateText.longDay(due, calendar: cal, now: Date()))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.leading, 48)
                                    .padding(.bottom, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            if showDateWheel {
                                WheelDatePicker(date: dueBinding, mode: .date, use24h: model.settings.use24HourTime)
                                    .frame(height: 180)
                            }
                            Divider().padding(.leading, 48)
                            CardRow(icon: "clock", title: "Time") {
                                Toggle("", isOn: Binding(get: { draft.dueHasTime }, set: { on in
                                    withAnimation {
                                        draft.dueHasTime = on
                                        if on, let d = draft.due {
                                            draft.due = DateMath.nextRoundHour(on: d, now: Date(), calendar: cal)
                                            showTimeWheel = true
                                        } else if let d = draft.due {
                                            draft.due = cal.startOfDay(for: d)
                                            showTimeWheel = false
                                        }
                                    }
                                })).labelsHidden()
                            }
                            if draft.dueHasTime {
                                Button { withAnimation { showTimeWheel.toggle(); showDateWheel = false } } label: {
                                    Text(model.time(due))
                                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(Theme.accent)
                                        .padding(.leading, 48)
                                        .padding(.bottom, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                if showTimeWheel {
                                    WheelDatePicker(date: dueBinding, mode: .time, use24h: model.settings.use24HourTime)
                                        .frame(height: 180)
                                }
                            }
                        }
                    }
                    .clipped()
                    Card {
                        Menu {
                            ForEach(model.reminderLists) { l in
                                Button(l.title + " · " + l.account.label) { draft.listID = l.id }
                            }
                        } label: {
                            CardRow(icon: "list.bullet", title: "List") {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(hex: model.colorHex(for: draft))).frame(width: 10, height: 10)
                                    Text(model.info(for: draft.listID)?.title ?? "Choose").foregroundStyle(Theme.ink2)
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                                }
                            }
                        }
                    }
                    Card {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "note.text").foregroundStyle(Theme.ink2).frame(width: 22).padding(.top, 2)
                            TextField("Note", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0 }), axis: .vertical)
                                .lineLimit(3...8)
                        }
                        .padding(14)
                    }
                    if let original {
                        Card {
                            Button { confirmDelete = true } label: {
                                Text("Delete task").font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.danger)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                        }
                        .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete task", role: .destructive) {
                                model.deleteTask(original)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.groupedBG.ignoresSafeArea())
        .onAppear {
            if draft.listID.isEmpty { draft.listID = model.defaultListID ?? "" }
            if original == nil { titleFocused = true }
        }
    }

    private var dueBinding: Binding<Date> {
        Binding(get: { draft.due ?? model.selectedDate }, set: { new in
            if draft.dueHasTime {
                draft.due = new
            } else {
                draft.due = cal.startOfDay(for: new)
            }
        })
    }

    private func save() {
        var t = draft
        t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if original == nil {
            // "Call the bank tomorrow 9am #work" fills in the due date and list.
            let parsed = NaturalLanguageParser(calendar: cal, now: Date()).parse(t.title)
            if parsed.recognisedAnything && !parsed.title.isEmpty {
                t.title = parsed.title
                if let list = model.match(tag: parsed.calendarTag, in: model.reminderLists) { t.listID = list.id }
                if parsed.date != nil || parsed.startMinute != nil {
                    let day = cal.startOfDay(for: parsed.date ?? t.due ?? model.selectedDate)
                    if let m = parsed.startMinute {
                        t.due = cal.date(byAdding: .minute, value: m, to: day)
                        t.dueHasTime = true
                    } else {
                        t.due = day
                    }
                }
            }
        }
        t.completionDate = t.isCompleted ? (t.completionDate ?? Date()) : nil
        model.saveTask(t, isNew: original == nil, previous: original)
        dismiss()
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Calendars & settings", pill: "Done", close: { dismiss() }, action: { dismiss() })
            Form {
                Section("Calendar") {
                    Picker("Week starts on", selection: $model.settings.weekStartsOnMonday) {
                        Text("Monday").tag(true)
                        Text("Sunday").tag(false)
                    }
                    Toggle("24-hour time", isOn: $model.settings.use24HourTime)
                    Toggle("Show tasks in calendar views", isOn: $model.settings.showTasksInCalendar)
                    Picker("Default event length", selection: $model.settings.defaultEventMinutes) {
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { Text(DateText.duration(minutes: $0)).tag($0) }
                    }
                    Picker("Default alert", selection: $model.settings.defaultAlert) {
                        ForEach(AlertOption.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Appearance") {
                    Picker("Theme", selection: $model.appearance) {
                        ForEach(Appearance.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    ForEach(model.calendars + model.reminderLists) { c in
                        Toggle(isOn: Binding(get: { !model.hiddenCalendarIDs.contains(c.id) },
                                             set: { model.setVisible(c.id, $0) })) {
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.title)
                                    Text("\(c.account.label) · \(c.isReminderList ? "Reminders" : "Calendar")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Visible calendars")
                } footer: {
                    Text("Daybook shows the iCloud, Google and Outlook accounts added in iOS Settings › Apps › Calendar › Calendar Accounts. Tasks are your Apple Reminders.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Theme.groupedBG.ignoresSafeArea())
        .accessibilityIdentifier("settingsView")
    }
}
