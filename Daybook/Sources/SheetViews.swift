import SwiftUI
import DaybookKit

struct SheetHost: View {
    @EnvironmentObject var model: AppModel
    let route: SheetRoute

    var body: some View {
        Group {
            switch route {
            case .event(let e):
                EventSheet(original: e, startEditing: false)
            case .newEvent(let s, let e, let allDay):
                EventSheet(newStart: s, newEnd: e, allDay: allDay)
            case .task(let t, let due):
                TaskEditor(original: t, defaultDue: due)
            case .settings:
                SettingsView()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
    }
}

/// Header shared by every sheet: round × on the left, title, pill on the right.
struct SheetHeader: View {
    let title: String
    let pill: String?
    var pillEnabled: Bool = true
    var pillProminent: Bool = true
    let close: () -> Void
    var action: () -> Void = {}

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 17, weight: .semibold))
                .accessibilityIdentifier("sheetTitle")
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.fill2))
                }
                .accessibilityIdentifier("closeButton")
                .accessibilityLabel("Close")
                Spacer()
                if let pill {
                    Button(action: action) {
                        Text(pill)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(pillProminent ? .white : Theme.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Capsule().fill(pillProminent ? Theme.accent : Theme.fill2))
                            .opacity(pillEnabled ? 1 : 0.4)
                    }
                    .disabled(!pillEnabled)
                    .accessibilityIdentifier("pill-\(pill)")
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

/// A rounded card in the grouped editor.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 14)
    }
}

struct CardRow<Trailing: View>: View {
    let icon: String
    let title: String
    var iconColor: Color = Theme.ink2
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(iconColor).frame(width: 22)
            Text(title).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            trailing
        }
        .font(.system(size: 16))
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }
}

// MARK: - Event sheet (detail ⇄ editor)

struct EventSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let original: CalEvent?
    @State private var editing: Bool
    @State private var draft: CalEvent
    @State private var titleText: String
    @State private var confirmDelete = false

    init(original: CalEvent, startEditing: Bool) {
        self.original = original
        _editing = State(initialValue: startEditing)
        _draft = State(initialValue: original)
        _titleText = State(initialValue: original.title)
    }

    init(newStart: Date, newEnd: Date, allDay: Bool) {
        original = nil
        _editing = State(initialValue: true)
        _draft = State(initialValue: CalEvent(id: "", title: "", calendarID: "", start: newStart, end: newEnd, isAllDay: allDay))
        _titleText = State(initialValue: "")
    }

    var body: some View {
        ZStack {
            if editing {
                EventEditor(draft: $draft, titleText: $titleText, isNew: original == nil,
                            close: { dismiss() }, save: save)
                    .transition(.opacity)
            } else if let e = original {
                detail(e).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: editing)
        .background(Theme.groupedBG.ignoresSafeArea())
    }

    private func save() {
        var e = draft
        e.title = titleText.trimmingCharacters(in: .whitespaces)
        model.saveEvent(e, isNew: original == nil, previous: original)
        dismiss()
    }

    // MARK: Detail

    private func detail(_ e: CalEvent) -> some View {
        let cal = model.calendar
        let info = model.info(for: e.calendarID)
        let c = Color(hex: model.colorHex(for: e))
        let editable = info?.allowsModifications ?? false
        return VStack(spacing: 0) {
            SheetHeader(title: "Event", pill: editable ? "Edit" : nil, pillProminent: false,
                        close: { dismiss() }, action: { editing = true })
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 6, height: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.title).font(.system(size: 22, weight: .bold))
                                .accessibilityIdentifier("detailTitle")
                            Text(dateLine(e, cal: cal)).font(.system(size: 15)).foregroundStyle(Theme.ink2)
                            Text(DateText.eventTimeRange(e, use24h: model.settings.use24HourTime, calendar: cal))
                                .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink2)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                    Card {
                        CardRow(icon: "calendar", title: "Calendar") {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: info?.colorHex ?? "#8e8e93")).frame(width: 10, height: 10)
                                Text(info?.title ?? "Unknown").foregroundStyle(Theme.ink2)
                            }
                        }
                        if let loc = e.location, !loc.isEmpty {
                            Divider().padding(.leading, 48)
                            CardRow(icon: "mappin.and.ellipse", title: loc) { EmptyView() }
                        }
                        Divider().padding(.leading, 48)
                        CardRow(icon: "bell", title: "Alert") { Text(e.alert.label).foregroundStyle(Theme.ink2) }
                        Divider().padding(.leading, 48)
                        CardRow(icon: "repeat", title: "Repeat") { Text(e.repeatRule.label).foregroundStyle(Theme.ink2) }
                        if let url = e.url, !url.isEmpty {
                            Divider().padding(.leading, 48)
                            CardRow(icon: "video", title: "Video call") {
                                if let link = URL(string: url) { Link("Join", destination: link) }
                            }
                        }
                        if !e.attendees.isEmpty {
                            Divider().padding(.leading, 48)
                            CardRow(icon: "person.2", title: e.attendees.joined(separator: ", ")) { EmptyView() }
                        }
                    }
                    if let notes = e.notes, !notes.isEmpty {
                        Card {
                            Text(notes).font(.system(size: 15)).foregroundStyle(Theme.ink)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if editable {
                        Card {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Text("Delete event").font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.danger)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .accessibilityIdentifier("deleteEvent")
                        }
                        .confirmationDialog("Delete this event?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete event", role: .destructive) {
                                model.deleteEvent(e)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private func dateLine(_ e: CalEvent, cal: Calendar) -> String {
        DateText.longDay(e.start, calendar: cal, now: Date())
    }
}

// MARK: - Editor

private enum WheelTarget: Equatable {
    case startDate, startTime, endDate, endTime
}

struct EventEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @Binding var draft: CalEvent
    @Binding var titleText: String
    let isNew: Bool
    let close: () -> Void
    let save: () -> Void

    @State private var wheel: WheelTarget?
    @State private var parsed = ParsedInput()
    @State private var touched: Set<String> = []   // fields the user changed by hand win over parsing
    @State private var showLocation = false
    @State private var showNote = false
    @State private var showVideo = false
    @State private var showAttendees = false
    @State private var showMoreColors = false
    @FocusState private var titleFocused: Bool

    private var cal: Calendar { model.calendar }
    private var color: Color { Color(hex: draft.customColorHex ?? model.info(for: draft.calendarID)?.colorHex ?? "#8e8e93") }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isNew ? "New Event" : "Edit Event", pill: "Save",
                        pillEnabled: !titleText.trimmingCharacters(in: .whitespaces).isEmpty && !draft.calendarID.isEmpty,
                        close: close, action: commit)
            ScrollView {
                VStack(spacing: 14) {
                    titleCard
                    whenCard
                    calendarCard
                    colorCard
                    alertCard
                    extrasCard
                }
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .bottom) { bottomBar }
        .foregroundStyle(Theme.ink)
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
    }

    private func commit() {
        // Use the cleaned-up title when the text was parsed.
        if isNew, parsed.recognisedAnything, !parsed.title.isEmpty { titleText = parsed.title }
        save()
    }

    // MARK: Title

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 12, height: 12)
                TextField(isNew ? "Lunch with Ioana tomorrow at 1pm" : "Title", text: $titleText, axis: .vertical)
                    .font(.system(size: 19, weight: .semibold))
                    .focused($titleFocused)
                    .accessibilityIdentifier("titleField")
                    .onChange(of: titleText) { _, new in if isNew { applyParse(new) } }
            }
            if isNew && !titleText.isEmpty {
                if parsed.recognisedAnything {
                    highlighted
                        .font(.system(size: 13))
                        .accessibilityIdentifier("parsePreview")
                } else {
                    Text("Type it the way you'd say it. Dates, times and #calendar are picked up.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
                }
            }
        }
        .padding(14)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.08), radius: 10, y: 4)
        .padding(.horizontal, 14)
    }

    /// The typed text with recognised words highlighted in the calendar colour.
    private var highlighted: Text {
        let ns = titleText as NSString
        var result = Text("")
        var cursor = 0
        for token in parsed.tokens where token.range.location >= cursor && NSMaxRange(token.range) <= ns.length {
            if token.range.location > cursor {
                result = result + Text(ns.substring(with: NSRange(location: cursor, length: token.range.location - cursor)))
                    .foregroundColor(Theme.ink2)
            }
            result = result + Text(ns.substring(with: token.range)).bold().foregroundColor(token.kind == .calendar ? color : Theme.accent)
            cursor = NSMaxRange(token.range)
        }
        if cursor < ns.length {
            result = result + Text(ns.substring(from: cursor)).foregroundColor(Theme.ink2)
        }
        return result
    }

    private func applyParse(_ text: String) {
        let parser = NaturalLanguageParser(calendar: cal, now: Date())
        parsed = parser.parse(text)
        if let match = model.match(tag: parsed.calendarTag, in: model.writableCalendars), !touched.contains("calendar") {
            draft.calendarID = match.id
        }
        if let loc = parsed.location, !touched.contains("location") {
            draft.location = loc
            showLocation = true
        }
        guard !touched.contains("time") else { return }
        let r = parser.resolve(parsed, selectedDay: model.selectedDate, defaultMinutes: model.settings.defaultEventMinutes)
        if parsed.recognisedAnything {
            draft.start = r.start
            draft.end = r.end
            draft.isAllDay = r.isAllDay
        }
    }

    // MARK: When

    private var whenCard: some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock").foregroundStyle(Theme.ink2).frame(width: 22).padding(.top, 22)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Starts").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink3)
                    tab(DateText.shortDay(draft.start, calendar: cal), target: .startDate)
                    if !draft.isAllDay { tab(model.time(draft.start), target: .startTime) }
                }
                Image(systemName: "arrow.right").foregroundStyle(Theme.ink3).padding(.top, 30)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ends").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink3)
                    tab(DateText.shortDay(endDay, calendar: cal), target: .endDate)
                    if !draft.isAllDay { tab(model.time(draft.end), target: .endTime) }
                }
                Spacer(minLength: 0)
            }
            .padding(14)

            if let wheel {
                WheelDatePicker(date: wheelBinding(wheel),
                                mode: (wheel == .startDate || wheel == .endDate) ? .date : .time,
                                use24h: model.settings.use24HourTime,
                                minimum: wheel == .endDate || wheel == .endTime ? minimumEnd(for: wheel) : nil)
                    .frame(height: 190)
                    .padding(.horizontal, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("wheel")
            }
            Divider().padding(.leading, 48)
            CardRow(icon: "sun.max", title: "All-day") {
                Toggle("", isOn: Binding(get: { draft.isAllDay }, set: { setAllDay($0) }))
                    .labelsHidden()
                    .accessibilityIdentifier("allDayToggle")
            }
        }
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: wheel)
    }

    /// The last day the event covers (for all-day events the stored end is exclusive).
    private var endDay: Date {
        draft.isAllDay ? cal.startOfDay(for: draft.end.addingTimeInterval(-1)) : draft.end
    }

    private func tab(_ text: String, target: WheelTarget) -> some View {
        let selected = wheel == target
        return Button {
            wheel = selected ? nil : target
            titleFocused = false
        } label: {
            Text(text)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(selected ? .white : Theme.accent)
                .padding(.leading, 10)
                .padding(.trailing, 16)
                .frame(height: 32)
                .background(ArrowTab().fill(selected ? Theme.accent : Theme.accentSoft))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-\(target)")
    }

    private func minimumEnd(for target: WheelTarget) -> Date? {
        draft.isAllDay ? cal.startOfDay(for: draft.start) : draft.start
    }

    private func wheelBinding(_ target: WheelTarget) -> Binding<Date> {
        Binding(get: {
            switch target {
            case .startDate, .startTime: return draft.start
            case .endDate, .endTime: return endDay
            }
        }, set: { new in
            touched.insert("time")
            switch target {
            case .startDate, .startTime:
                // Moving the start keeps the duration.
                let duration = draft.end.timeIntervalSince(draft.start)
                draft.start = draft.isAllDay ? cal.startOfDay(for: new) : new
                draft.end = draft.start.addingTimeInterval(duration)
            case .endDate, .endTime:
                if draft.isAllDay {
                    let day = max(cal.startOfDay(for: new), cal.startOfDay(for: draft.start))
                    draft.end = cal.date(byAdding: .day, value: 1, to: day) ?? day
                } else {
                    draft.end = max(new, draft.start.addingTimeInterval(5 * 60))
                }
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
                if wheel == .startTime || wheel == .endTime { wheel = nil }
            } else {
                let s = DateMath.nextRoundHour(on: draft.start, now: Date(), calendar: cal)
                draft.start = s
                draft.end = cal.date(byAdding: .minute, value: model.settings.defaultEventMinutes, to: s) ?? s
            }
            draft.isAllDay = on
        }
    }

    // MARK: Calendar, colour, alert, repeat

    private var calendarCard: some View {
        Card {
            Menu {
                ForEach(model.writableCalendars) { c in
                    Button {
                        touched.insert("calendar")
                        draft.calendarID = c.id
                    } label: {
                        Label(c.title + " · " + c.account.label, systemImage: c.id == draft.calendarID ? "checkmark" : "circle.fill")
                    }
                }
            } label: {
                CardRow(icon: "calendar", title: "Calendar") {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: model.info(for: draft.calendarID)?.colorHex ?? "#8e8e93")).frame(width: 10, height: 10)
                        Text(model.info(for: draft.calendarID)?.title ?? "Choose").foregroundStyle(Theme.ink2)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                    }
                }
            }
            .accessibilityIdentifier("calendarPicker")
        }
    }

    private var colorCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Custom Event Color").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink3)
                HStack(spacing: 14) {
                    swatch(nil, name: "Calendar")
                    ForEach(Theme.swatches.indices, id: \.self) { i in swatch(Theme.swatches[i].hex, name: Theme.swatches[i].name) }
                    VStack(spacing: 4) {
                        Button { withAnimation { showMoreColors.toggle() } } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(AngularGradient(colors: Theme.morePalette.map { Color(hex: $0) } + [Color(hex: Theme.morePalette[0])], center: .center)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        Text("More").font(.system(size: 10.5)).foregroundStyle(Theme.ink2)
                    }
                }
                if showMoreColors {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(Theme.morePalette, id: \.self) { hex in swatch(hex, name: nil) }
                    }
                    .transition(.opacity)
                }
            }
            .padding(14)
        }
    }

    private func swatch(_ hex: String?, name: String?) -> some View {
        let selected = draft.customColorHex == hex
        let fill = Color(hex: hex ?? model.info(for: draft.calendarID)?.colorHex ?? "#8e8e93")
        return VStack(spacing: 4) {
            Button { draft.customColorHex = hex } label: {
                Circle().fill(fill)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: selected ? 2 : 0).padding(-3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name ?? hex ?? "Calendar colour")
            if let name { Text(name).font(.system(size: 10.5)).foregroundStyle(Theme.ink2) }
        }
    }

    private var alertCard: some View {
        Card {
            Menu {
                Picker("Alert", selection: $draft.alert) {
                    ForEach(AlertOption.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                CardRow(icon: "bell", title: "Alert") {
                    Text(draft.alert.label).foregroundStyle(Theme.ink2)
                }
            }
            Divider().padding(.leading, 48)
            Menu {
                Picker("Repeat", selection: $draft.repeatRule) {
                    ForEach(RepeatRule.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                CardRow(icon: "repeat", title: "Repeat") {
                    Text(draft.repeatRule.label).foregroundStyle(Theme.ink2)
                }
            }
        }
    }

    // MARK: Location, attendees, video, note

    @ViewBuilder private var extrasCard: some View {
        if showLocation || showNote || showVideo || showAttendees {
            Card {
                if showLocation {
                    field("mappin.and.ellipse", "Location", text: Binding(get: { draft.location ?? "" },
                                                                          set: { touched.insert("location"); draft.location = $0 }))
                }
                if showVideo {
                    field("video", "Video call link", text: Binding(get: { draft.url ?? "" }, set: { draft.url = $0 }))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                if showAttendees {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.2").foregroundStyle(Theme.ink2).frame(width: 22)
                        Text(draft.attendees.isEmpty
                             ? "iOS lets only the Calendar app send invitations. Add people there; they will show up here."
                             : draft.attendees.joined(separator: ", "))
                            .font(.system(size: 14)).foregroundStyle(Theme.ink2)
                    }
                    .padding(14)
                }
                if showNote {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "note.text").foregroundStyle(Theme.ink2).frame(width: 22).padding(.top, 2)
                        TextField("Note", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0 }), axis: .vertical)
                            .lineLimit(3...8)
                    }
                    .padding(14)
                }
            }
        }
    }

    private func field(_ icon: String, _ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.ink2).frame(width: 22)
            TextField(placeholder, text: text)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            barButton("mappin.and.ellipse", "Location", on: showLocation) { showLocation.toggle() }
            barButton("person.2", "Attendees", on: showAttendees) { showAttendees.toggle() }
            barButton("video", "Video call", on: showVideo) { showVideo.toggle() }
            barButton("note.text", "Note", on: showNote) { showNote.toggle() }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func barButton(_ icon: String, _ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { action() } } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17))
                Text(title).font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(on ? Theme.accent : Theme.ink2)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bar-\(title)")
    }
}

/// The arrow-shaped date and time tabs in the When card.
struct ArrowTab: Shape {
    func path(in r: CGRect) -> Path {
        let tip: CGFloat = 9, radius: CGFloat = 7
        var p = Path()
        p.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tip, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - tip + 2, y: r.minY + 2), control: CGPoint(x: r.maxX - tip + 1.5, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 1, y: r.midY - 1.5))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 1, y: r.midY + 1.5), control: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX - tip + 2, y: r.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: r.maxX - tip, y: r.maxY), control: CGPoint(x: r.maxX - tip + 1.5, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// UIDatePicker wheels with 5-minute steps and a 24-hour or 12-hour clock.
struct WheelDatePicker: UIViewRepresentable {
    enum Mode { case date, time }
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
        p.datePickerMode = mode == .date ? .date : .time
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
