import SwiftUI
import DaybookKit

struct SheetHost: View {
    @EnvironmentObject var model: AppModel
    let route: SheetRoute

    var body: some View {
        Group {
            switch route {
            case .event(let e):
                EventSheet(original: e)
            case .newEvent(let s, let e, let allDay):
                EventEditor(original: nil, start: s, end: e, allDay: allDay)
                    .presentationDetents([.large])
            case .task(let t, let due):
                TaskEditor(original: t, defaultDue: due)
                    .presentationDetents([.large])
            case .settings:
                SettingsView()
                    .presentationDetents([.large])
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(18)
        .presentationBackground(Theme.groupedBG)
    }
}

/// Sheet header: "Cancel" on the left, title, a text action ("Save", "Done") on the right.
struct SheetHeader: View {
    let title: String
    let pill: String?
    var pillEnabled: Bool = true
    var pillProminent: Bool = true
    let close: () -> Void
    var action: () -> Void = {}

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 19, weight: .medium))
                .accessibilityIdentifier("sheetTitle")
            HStack {
                Button("Cancel", action: close)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink2)
                    .accessibilityIdentifier("closeButton")
                Spacer()
                if let pill {
                    Button(pill, action: action)
                        .font(.system(size: 17, weight: pillProminent ? .semibold : .regular))
                        .foregroundStyle(pillEnabled ? Theme.accent : Theme.ink3)
                        .disabled(!pillEnabled)
                        .accessibilityIdentifier("pill-\(pill)")
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }
}

/// A full-width band, as in the grouped editor of the reference screenshots.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sheet)
    }
}

struct CardRow<Trailing: View>: View {
    let icon: String
    let title: String
    var iconColor: Color = Theme.ink2
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon).foregroundStyle(iconColor).frame(width: 24)
            Text(title).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            trailing
        }
        .font(.system(size: 18))
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

// MARK: - Event detail

struct EventSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let original: CalEvent
    @State private var editing = false
    @State private var detent: PresentationDetent = .medium
    @State private var confirmDelete = false

    init(original: CalEvent) { self.original = original }

    var body: some View {
        ZStack {
            if editing {
                EventEditor(original: original, start: original.start, end: original.end, allDay: original.isAllDay)
                    .transition(.opacity)
            } else {
                detail.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: editing)
        .presentationDetents(editing ? [.large] : [.medium, .large], selection: $detent)
    }

    private var detail: some View {
        let e = original
        let cal = model.calendar
        let info = model.info(for: e.calendarID)
        let editable = info?.allowsModifications ?? false
        let days = e.days(in: cal)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 22) {
                Circle().fill(Color(hex: model.colorHex(for: e))).frame(width: 20, height: 20).padding(.top, 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text(e.title).font(.system(size: 30, weight: .bold))
                        .accessibilityIdentifier("detailTitle")
                    if days.count > 1 {
                        Text(DateText.fullDay(days.first!, calendar: cal) + " –")
                            .font(.system(size: 20)).foregroundStyle(Theme.ink2)
                        Text(DateText.fullDay(days.last!, calendar: cal))
                            .font(.system(size: 20)).foregroundStyle(Theme.ink2)
                    } else {
                        Text(DateText.fullDay(e.start, calendar: cal, now: Date()))
                            .font(.system(size: 20)).foregroundStyle(Theme.ink2)
                    }
                    Text(e.isAllDay ? "All day" : "\(model.time(e.start)) - \(model.time(e.end))")
                        .font(.system(size: 20, weight: .semibold))
                    if let info {
                        Text("\(info.title) (\(info.account.label))")
                            .font(.system(size: 18)).foregroundStyle(Theme.ink2)
                            .padding(.top, 10)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 34)
            .padding(.bottom, 20)

            Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 66)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if e.alert != .none { infoRow("bell.fill", e.alert.label) }
                    if e.repeatRule != .never { infoRow("repeat", "Repeats " + e.repeatRule.label.lowercased()) }
                    if let loc = e.location, !loc.isEmpty { infoRow("mappin.and.ellipse", loc) }
                    if let url = e.url, !url.isEmpty, let link = URL(string: url) {
                        HStack(spacing: 22) {
                            Image(systemName: "video.fill").foregroundStyle(Theme.ink3).frame(width: 22)
                            Link("Join video call", destination: link).font(.system(size: 19))
                        }
                        .padding(.horizontal, 22).padding(.vertical, 14)
                    }
                    if !e.attendees.isEmpty { infoRow("person.2.fill", e.attendees.joined(separator: ", ")) }
                    if let notes = e.notes, !notes.isEmpty { infoRow("text.alignleft", notes) }
                }
                .padding(.top, 10)
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack {
                if editable {
                    Button("Edit") { editing = true; detent = .large }
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("pill-Edit")
                    Spacer()
                    Button { confirmDelete = true } label: {
                        Image(systemName: "trash").font(.system(size: 22, weight: .medium)).foregroundStyle(Theme.danger)
                    }
                    .accessibilityIdentifier("deleteEvent")
                    .accessibilityLabel("Delete event")
                } else {
                    Text("This calendar is read-only").font(.system(size: 15)).foregroundStyle(Theme.ink3)
                    Spacer()
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.sheet.ignoresSafeArea())
        .confirmationDialog("Delete this event?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete event", role: .destructive) {
                model.deleteEvent(e)
                dismiss()
            }
        }
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 22) {
            Image(systemName: icon).foregroundStyle(Theme.ink3).frame(width: 22).padding(.top, 2)
            Text(text).font(.system(size: 19))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}

// MARK: - Editor (edit and new)

private enum WhenSide: Equatable { case start, end }
private enum NewKind: String { case task = "Task", event = "Event" }

struct EventEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let original: CalEvent?
    @State private var draft: CalEvent
    @State private var titleText: String
    @State private var side: WhenSide?
    @State private var parsed = ParsedInput()
    @State private var touched: Set<String> = []   // fields changed by hand win over parsing
    @State private var showDetails: Bool
    @State private var showColors: Bool
    @State private var showMoreColors = false
    @State private var showLocation = false
    @State private var showNote = false
    @State private var showVideo = false
    @State private var showAttendees = false
    @State private var kind: NewKind = .event
    @State private var confirmDelete = false
    @FocusState private var titleFocused: Bool

    init(original: CalEvent?, start: Date, end: Date, allDay: Bool) {
        self.original = original
        let e = original ?? CalEvent(id: "", title: "", calendarID: "", start: start, end: end, isAllDay: allDay)
        _draft = State(initialValue: e)
        _titleText = State(initialValue: e.title)
        _showDetails = State(initialValue: original != nil)
        _showColors = State(initialValue: original?.customColorHex != nil || original != nil)
    }

    private var isNew: Bool { original == nil }
    private var cal: Calendar { model.calendar }
    private var calendarColor: Color { Color(hex: model.info(for: draft.calendarID)?.colorHex ?? "#8e8e93") }
    private var color: Color { Color(hex: draft.customColorHex ?? model.info(for: draft.calendarID)?.colorHex ?? "#8e8e93") }
    private var showWhen: Bool { !isNew || showDetails || parsed.recognisedAnything }
    private var canSave: Bool {
        let t = (isNew && parsed.recognisedAnything ? parsed.title : titleText).trimmingCharacters(in: .whitespaces)
        if kind == .task { return !t.isEmpty && model.defaultListID != nil }
        return !t.isEmpty && !draft.calendarID.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isNew ? (kind == .task ? "New Task" : "New Event") : "Edit Event", pill: "Save",
                        pillEnabled: canSave, close: { dismiss() }, action: commit)
            ScrollView {
                VStack(spacing: 0) {
                    titleCard
                    if showWhen {
                        if kind == .task { taskDueRow } else { whenCard }
                    }
                    if showDetails && kind == .event {
                        detailsSection
                    } else if showDetails && kind == .task {
                        taskListRow.padding(.top, 22)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { showDetails = true }
                        } label: {
                            Text("Show Details")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 34)
                                .frame(height: 50)
                                .background(Capsule().fill(Theme.sheet))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 30)
                        .accessibilityIdentifier("showDetails")
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.groupedBG.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if isNew && titleFocused { kindToggle }
        }
        .onAppear {
            if draft.calendarID.isEmpty { draft.calendarID = model.defaultCalendarID ?? "" }
            if isNew {
                draft.alert = model.settings.defaultAlert
                titleFocused = true
            }
            showLocation = !(draft.location ?? "").isEmpty
            showNote = !(draft.notes ?? "").isEmpty
            showVideo = !(draft.url ?? "").isEmpty
        }
        .confirmationDialog("Delete this event?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete event", role: .destructive) {
                if let original { model.deleteEvent(original) }
                dismiss()
            }
        }
    }

    private func commit() {
        let title = (isNew && parsed.recognisedAnything && !parsed.title.isEmpty ? parsed.title : titleText)
            .trimmingCharacters(in: .whitespaces)
        if kind == .task {
            var t = TaskItem(id: "", title: title, listID: model.match(tag: parsed.calendarTag, in: model.reminderLists)?.id
                             ?? model.defaultListID ?? "")
            if parsed.date != nil || parsed.startMinute != nil {
                let day = cal.startOfDay(for: parsed.date ?? model.selectedDate)
                if let m = parsed.startMinute {
                    t.due = cal.date(byAdding: .minute, value: m, to: day); t.dueHasTime = true
                } else {
                    t.due = day
                }
            }
            model.saveTask(t, isNew: true, previous: nil)
        } else {
            var e = draft
            e.title = title
            model.saveEvent(e, isNew: isNew, previous: original)
        }
        dismiss()
    }

    // MARK: Title

    @ViewBuilder private var titleCard: some View {
        if isNew {
            HStack(spacing: 10) {
                // The field wraps instead of scrolling sideways, so the highlight
                // layer underneath stays lined up with the typed words.
                ZStack(alignment: .topLeading) {
                    highlightLayer
                    TextField("", text: $titleText,
                              prompt: Text(kind == .task ? "Renew passport by next Friday" : "Plan my week tomorrow at 3PM")
                                .foregroundColor(.white.opacity(0.6)),
                              axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { if canSave { commit() } }
                        .accessibilityIdentifier("titleField")
                        .onChange(of: titleText) { _, new in
                            // Return in a wrapping field inserts a newline; treat it as Done.
                            if new.contains("\n") {
                                titleText = new.replacingOccurrences(of: "\n", with: "")
                                titleFocused = false
                                return
                            }
                            applyParse(new)
                        }
                }
                if !titleText.isEmpty {
                    Button { titleText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(minHeight: 66)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
            .padding(.horizontal, 14)
            .padding(.bottom, 22)
            .background(Theme.sheet)
        } else {
            HStack(spacing: 18) {
                Circle().fill(color).frame(width: 12, height: 12)
                TextField("Title", text: $titleText)
                    .font(.system(size: 21, weight: .medium))
                    .accessibilityIdentifier("titleField")
            }
            .padding(.horizontal, 22)
            .frame(height: 66)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.fill))
            .padding(.horizontal, 14)
            .padding(.bottom, 22)
            .background(Theme.sheet)
        }
    }

    /// Clear text with tinted backgrounds behind the words the parser recognised.
    private var highlightLayer: some View {
        var a = AttributedString(titleText)
        a.foregroundColor = Color.clear
        let ns = titleText as NSString
        for token in parsed.tokens where NSMaxRange(token.range) <= ns.length {
            if let r = Range(token.range, in: titleText),
               let lower = AttributedString.Index(r.lowerBound, within: a),
               let upper = AttributedString.Index(r.upperBound, within: a) {
                a[lower..<upper].backgroundColor = Color.white.opacity(0.28)
            }
        }
        return Text(a)
            .font(.system(size: 19, weight: .medium))
            .lineLimit(1...4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func applyParse(_ text: String) {
        let parser = NaturalLanguageParser(calendar: cal, now: Date())
        withAnimation(.easeInOut(duration: 0.2)) { parsed = parser.parse(text) }
        if let match = model.match(tag: parsed.calendarTag, in: model.writableCalendars), !touched.contains("calendar") {
            draft.calendarID = match.id
        }
        if let loc = parsed.location, !touched.contains("location") {
            draft.location = loc
            showLocation = true
        }
        guard !touched.contains("time"), parsed.recognisedAnything else { return }
        let r = parser.resolve(parsed, selectedDay: model.selectedDate, defaultMinutes: model.settings.defaultEventMinutes)
        draft.start = r.start
        draft.end = r.end
        draft.isAllDay = r.isAllDay
    }

    private var kindToggle: some View {
        HStack(spacing: 0) {
            kindButton(.task, icon: "checkmark.circle.fill")
            Rectangle().fill(Theme.line).frame(width: 1, height: 28)
            kindButton(.event, icon: "clock.fill")
        }
        .padding(.vertical, 8)
        .background(Theme.fill)
    }

    private func kindButton(_ k: NewKind, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { kind = k }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(k.rawValue)
            }
            .font(.system(size: 18))
            .foregroundStyle(kind == k ? .white : Theme.ink2)
            .padding(.horizontal, 26)
            .frame(height: 40)
            .background(Capsule().fill(kind == k ? Theme.accent : .clear))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kind-\(k.rawValue)")
    }

    // MARK: When

    private var endDay: Date {
        draft.isAllDay ? cal.startOfDay(for: draft.end.addingTimeInterval(-1)) : draft.end
    }

    private var whenCard: some View {
        Card {
            Rectangle().fill(Theme.line).frame(height: 1)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                    if side == .start {
                        WhenHalfShape(isLeft: true).fill(Theme.accent)
                    } else if side == .end {
                        WhenHalfShape(isLeft: false).fill(Theme.accent)
                    } else {
                        WhenDivider().stroke(Theme.line, lineWidth: 1)
                    }
                    Image(systemName: "clock.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(side == .start ? .white : Theme.ink3)
                        .position(x: 39, y: h / 2)
                    whenLabel(date: draft.start, selected: side == .start)
                        .frame(width: w / 2 - 80, height: h, alignment: .leading)
                        .offset(x: 78)
                    whenLabel(date: endDay, selected: side == .end)
                        .frame(width: w / 2 - 40, height: h, alignment: .leading)
                        .offset(x: w / 2 + 28)
                    HStack(spacing: 0) {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { toggle(.start) }
                            .accessibilityElement()
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Starts")
                            .accessibilityIdentifier("when-start")
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { toggle(.end) }
                            .accessibilityElement()
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Ends")
                            .accessibilityIdentifier("when-end")
                    }
                }
            }
            .frame(height: 92)
            if let side {
                WheelDatePicker(date: wheelBinding(side),
                                mode: draft.isAllDay ? .date : .dateAndTime,
                                use24h: model.settings.use24HourTime,
                                minimum: side == .end ? (draft.isAllDay ? cal.startOfDay(for: draft.start) : draft.start) : nil)
                    .frame(height: 216)
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("wheel")
                Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 22)
            } else {
                Rectangle().fill(Theme.line).frame(height: 1)
            }
            HStack {
                Text("All-day event").font(.system(size: 19))
                Spacer()
                Toggle("", isOn: Binding(get: { draft.isAllDay }, set: { setAllDay($0) }))
                    .labelsHidden()
                    .accessibilityIdentifier("allDayToggle")
            }
            .padding(.horizontal, 24)
            .frame(height: 64)
        }
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: side)
    }

    private func whenLabel(date: Date, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(draft.isAllDay ? DateText.shortDayComma(date, calendar: cal).components(separatedBy: ",").first ?? ""
                                : DateText.shortDayComma(date, calendar: cal))
                .font(.system(size: 18))
            Text(draft.isAllDay ? "\(cal.component(.day, from: date)) \(DateText.monthName(date, calendar: cal, short: true))"
                                : model.time(date))
                .font(.system(size: 28, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(selected ? .white : Theme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func toggle(_ s: WhenSide) {
        titleFocused = false
        side = side == s ? nil : s
    }

    private func wheelBinding(_ s: WhenSide) -> Binding<Date> {
        Binding(get: { s == .start ? draft.start : endDay }, set: { new in
            touched.insert("time")
            if s == .start {
                // Moving the start keeps the duration.
                let duration = draft.end.timeIntervalSince(draft.start)
                draft.start = draft.isAllDay ? cal.startOfDay(for: new) : new
                draft.end = draft.start.addingTimeInterval(duration)
            } else if draft.isAllDay {
                let day = max(cal.startOfDay(for: new), cal.startOfDay(for: draft.start))
                draft.end = cal.date(byAdding: .day, value: 1, to: day) ?? day
            } else {
                draft.end = max(new, draft.start.addingTimeInterval(5 * 60))
            }
        })
    }

    private func setAllDay(_ on: Bool) {
        touched.insert("time")
        withAnimation(.easeInOut(duration: 0.2)) {
            if on {
                let first = cal.startOfDay(for: draft.start)
                let last = cal.startOfDay(for: draft.end.addingTimeInterval(-1))
                draft.start = first
                draft.end = cal.date(byAdding: .day, value: 1, to: max(first, last)) ?? first
            } else {
                let s = DateMath.nextRoundHour(on: draft.start, now: Date(), calendar: cal)
                draft.start = s
                draft.end = cal.date(byAdding: .minute, value: model.settings.defaultEventMinutes, to: s) ?? s
            }
            draft.isAllDay = on
        }
    }

    // MARK: Task mode rows

    private var taskDueRow: some View {
        Card {
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 18) {
                Image(systemName: "checkmark.circle").font(.system(size: 22)).foregroundStyle(Theme.ink3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Due").font(.system(size: 16)).foregroundStyle(Theme.ink2)
                    Text(taskDueText).font(.system(size: 22, weight: .semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(height: 84)
        }
    }

    private var taskDueText: String {
        guard parsed.date != nil || parsed.startMinute != nil else { return "No date" }
        let day = parsed.date ?? model.selectedDate
        var s = DateText.shortDayComma(day, calendar: cal)
        if let m = parsed.startMinute { s += "  " + DateText.time(minutes: m, use24h: model.settings.use24HourTime) }
        return s
    }

    private var taskListRow: some View {
        let listID = model.match(tag: parsed.calendarTag, in: model.reminderLists)?.id ?? model.defaultListID ?? ""
        return Card {
            CardRow(icon: "list.bullet", title: model.info(for: listID)?.title ?? "Reminders") {
                Circle().fill(Color(hex: model.info(for: listID)?.colorHex ?? "#8e8e93")).frame(width: 14, height: 14)
            }
        }
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 22)
            Card {
                Menu {
                    ForEach(model.writableCalendars) { c in
                        Button {
                            touched.insert("calendar")
                            draft.calendarID = c.id
                        } label: {
                            Label("\(c.title) (\(c.account.label))", systemImage: c.id == draft.calendarID ? "checkmark" : "circle.fill")
                        }
                    }
                } label: {
                    HStack(spacing: 30) {
                        Circle().fill(calendarColor).frame(width: 22, height: 22)
                        Text(model.info(for: draft.calendarID)?.title ?? "Choose calendar").font(.system(size: 19))
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.ink2)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .frame(height: 76)
                }
                .accessibilityIdentifier("calendarPicker")
                Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 80).padding(.trailing, 80)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showColors.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Text("Custom Event Color").font(.system(size: 16))
                        Image(systemName: "chevron.up").font(.system(size: 13, weight: .semibold))
                            .rotationEffect(.degrees(showColors ? 0 : 180))
                    }
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                if showColors {
                    HStack {
                        swatch(nil)
                        ForEach(Theme.swatches.indices, id: \.self) { i in
                            Spacer(minLength: 0)
                            swatch(Theme.swatches[i].hex, name: Theme.swatches[i].name)
                        }
                        Spacer(minLength: 0)
                        Button { withAnimation { showMoreColors.toggle() } } label: { MorePaletteIcon() }
                            .buttonStyle(.plain)
                            .accessibilityLabel("More colours")
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                    if showMoreColors {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                            ForEach(Theme.morePalette, id: \.self) { hex in swatch(hex) }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                    }
                }
            }
            Color.clear.frame(height: 22)
            Card {
                Menu {
                    Picker("Alert", selection: $draft.alert) {
                        ForEach(AlertOption.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    CardRow(icon: "bell.fill", title: draft.alert == .none ? "Add alert" : "Alert \(draft.alert.label)") {
                        if draft.alert == .none {
                            Image(systemName: "chevron.right").foregroundStyle(Theme.ink2)
                        }
                    }
                }
                .overlay(alignment: .trailing) {
                    if draft.alert != .none {
                        Button { draft.alert = .none } label: {
                            Image(systemName: "xmark").font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Theme.ink2).frame(width: 56, height: 56)
                        }
                        .accessibilityLabel("Remove alert")
                    }
                }
                Rectangle().fill(Theme.line).frame(height: 1)
                Menu {
                    Picker("Repeat", selection: $draft.repeatRule) {
                        ForEach(RepeatRule.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    CardRow(icon: "repeat", title: draft.repeatRule == .never ? "Repeat" : "Repeat \(draft.repeatRule.label.lowercased())") {
                        Image(systemName: "chevron.right").foregroundStyle(Theme.ink2)
                    }
                }
            }
            extras
            actionBar
                .padding(.top, 22)
            if !isNew {
                Button { confirmDelete = true } label: {
                    Text("Delete").font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.sheet))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 70)
                .accessibilityIdentifier("deleteEvent")
            }
        }
        .transition(.opacity)
    }

    private func swatch(_ hex: String?, name: String? = nil) -> some View {
        let selected = draft.customColorHex == hex
        return Button { draft.customColorHex = hex } label: {
            ZStack {
                if let hex {
                    Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                } else {
                    Circle().fill(Theme.ink2.opacity(0.8)).frame(width: 34, height: 34)
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.sheet)
                }
                if selected {
                    Circle().stroke(Theme.ink2, lineWidth: 3).frame(width: 46, height: 46)
                }
            }
            .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name ?? (hex == nil ? "Calendar colour" : hex!))
    }

    @ViewBuilder private var extras: some View {
        if showLocation || showNote || showVideo || showAttendees {
            Color.clear.frame(height: 22)
            Card {
                if showLocation {
                    field("mappin.and.ellipse", "Location", text: Binding(get: { draft.location ?? "" },
                                                                          set: { touched.insert("location"); draft.location = $0 }))
                }
                if showVideo {
                    field("video.fill", "Video call link", text: Binding(get: { draft.url ?? "" }, set: { draft.url = $0 }))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                if showAttendees {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "person.fill").foregroundStyle(Theme.ink2).frame(width: 24)
                        Text(draft.attendees.isEmpty
                             ? "iOS lets only the Calendar app send invitations. Add people there; they will show up here."
                             : draft.attendees.joined(separator: ", "))
                            .font(.system(size: 15)).foregroundStyle(Theme.ink2)
                    }
                    .padding(20)
                }
                if showNote {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "text.alignleft").foregroundStyle(Theme.ink2).frame(width: 24).padding(.top, 2)
                        TextField("Note", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0 }), axis: .vertical)
                            .lineLimit(3...8)
                    }
                    .padding(20)
                }
            }
        }
    }

    private func field(_ icon: String, _ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon).foregroundStyle(Theme.ink2).frame(width: 24)
            TextField(placeholder, text: text).font(.system(size: 18))
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            barButton("mappin.and.ellipse", "Location", on: showLocation) { showLocation.toggle() }
            barButton("person.fill", "Attendees", on: showAttendees) { showAttendees.toggle() }
            barButton("video.fill", "Video call", on: showVideo) { showVideo.toggle() }
            barButton("list.bullet.rectangle.fill", "Note", on: showNote) { showNote.toggle() }
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.sheet))
        .padding(.horizontal, 14)
    }

    private func barButton(_ icon: String, _ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { action() } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 22))
                Text(title).font(.system(size: 15))
            }
            .foregroundStyle(on ? Theme.accent : Theme.ink2)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bar-\(title)")
    }
}

/// Blue arrow behind the selected half of the start/end row.
struct WhenHalfShape: Shape {
    let isLeft: Bool
    func path(in r: CGRect) -> Path {
        let mid = r.width * 0.5, tip: CGFloat = 32
        var p = Path()
        if isLeft {
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: mid - tip, y: 0))
            p.addLine(to: CGPoint(x: mid + 2, y: r.height / 2))
            p.addLine(to: CGPoint(x: mid - tip, y: r.height))
            p.addLine(to: CGPoint(x: 0, y: r.height))
        } else {
            p.move(to: CGPoint(x: mid - tip, y: 0))
            p.addLine(to: CGPoint(x: r.width, y: 0))
            p.addLine(to: CGPoint(x: r.width, y: r.height))
            p.addLine(to: CGPoint(x: mid - tip, y: r.height))
            p.addLine(to: CGPoint(x: mid + 2, y: r.height / 2))
        }
        p.closeSubpath()
        return p
    }
}

/// The thin chevron between start and end when neither is selected.
struct WhenDivider: Shape {
    func path(in r: CGRect) -> Path {
        let mid = r.width * 0.5, tip: CGFloat = 32
        var p = Path()
        p.move(to: CGPoint(x: mid - tip, y: 0))
        p.addLine(to: CGPoint(x: mid + 2, y: r.height / 2))
        p.addLine(to: CGPoint(x: mid - tip, y: r.height))
        return p
    }
}

/// The multicoloured dots button that opens more colours.
struct MorePaletteIcon: View {
    var body: some View {
        let colors: [Color] = [.orange, .yellow, .green, .blue, .purple, .pink]
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) / 6 * 2 * .pi - .pi / 2
                Circle().fill(colors[i]).frame(width: 11, height: 11)
                    .offset(x: CGFloat(cos(angle)) * 14, y: CGFloat(sin(angle)) * 14)
            }
            Circle().fill(Color.red).frame(width: 11, height: 11)
        }
        .frame(width: 50, height: 50)
    }
}

/// UIDatePicker wheels with 5-minute steps and a 24-hour or 12-hour clock.
struct WheelDatePicker: UIViewRepresentable {
    enum Mode { case date, time, dateAndTime }
    @Binding var date: Date
    let mode: Mode
    let use24h: Bool
    var minimum: Date?

    func makeUIView(context: Context) -> UIDatePicker {
        let p = UIDatePicker()
        p.preferredDatePickerStyle = .wheels
        p.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        p.setContentHuggingPriority(.defaultLow, for: .horizontal)
        p.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return p
    }

    func updateUIView(_ p: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        switch mode {
        case .date: p.datePickerMode = .date
        case .time: p.datePickerMode = .time
        case .dateAndTime: p.datePickerMode = .dateAndTime
        }
        p.minuteInterval = 5
        p.locale = Locale(identifier: use24h ? "en_GB" : "en_US")
        p.minimumDate = minimum
        if abs(p.date.timeIntervalSince(date)) > 1 { p.setDate(date, animated: false) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: WheelDatePicker
        init(parent: WheelDatePicker) { self.parent = parent }
        @objc func changed(_ sender: UIDatePicker) { parent.date = sender.date }
    }
}
