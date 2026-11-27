import SwiftUI
import DaybookKit

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Namespace private var tabNS

    var body: some View {
        ZStack(alignment: .leading) {
            Theme.headerGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                card
            }
            if model.drawerOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { model.drawerOpen = false } }
                    .transition(.opacity)
                    .accessibilityIdentifier("drawerBackdrop")
                DrawerView()
                    .transition(.move(edge: .leading))
            }
        }
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $model.sheet) { route in
            SheetHost(route: route)
                .environmentObject(model)
                .preferredColorScheme(model.appearance.scheme)
        }
        .alert("Couldn't save", isPresented: Binding(get: { model.errorMessage != nil },
                                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) { model.drawerOpen = true }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 36, height: 40)
            }
            .accessibilityIdentifier("menuButton")
            .accessibilityLabel("Menu")

            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ForEach(ViewMode.allCases) { m in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            model.mode = m
                            model.searchOpen = false
                        }
                    } label: {
                        Text(m.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background {
                                if model.mode == m {
                                    Capsule().fill(Theme.accent)
                                        .matchedGeometryEffect(id: "pill", in: tabNS)
                                }
                            }
                    }
                    .accessibilityIdentifier("tab-\(m.rawValue)")
                    .accessibilityAddTraits(model.mode == m ? .isSelected : [])
                }
            }
            Spacer(minLength: 0)

            Button { model.openNew() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 36, height: 40)
            }
            .accessibilityIdentifier("addButton")
            .accessibilityLabel(model.mode == .tasks ? "New task" : "New event")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 0) {
            TitleRow()
            if model.searchOpen {
                SearchField()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if model.access == .denied && !model.isDemo {
                AccessBanner()
            }
            if [.month, .week, .day].contains(model.mode) && !(model.searchOpen && !model.searchText.isEmpty) {
                MonthStrip()
            }
        }
        .background(Theme.bg)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder private var content: some View {
        if model.searchOpen && !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            SearchResultsView()
        } else {
            switch model.mode {
            case .month: MonthView()
            case .week: WeekView()
            case .day: DayView()
            case .list: AgendaView()
            case .tasks: TasksView()
            }
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast = model.toast {
            HStack(spacing: 14) {
                Text(toast.message).font(.subheadline.weight(.medium))
                if let undo = toast.undo {
                    Button("Undo") {
                        undo()
                        model.toast = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("undoButton")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Theme.line))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .padding(.bottom, 70)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
            .accessibilityIdentifier("toast")
        }
    }
}

struct TitleRow: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let cal = model.calendar
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title(cal))
                .font(.system(size: 26))
                .accessibilityIdentifier("titleLabel")
            Spacer()
            if !cal.isDate(model.selectedDate, inSameDayAs: Date()) || model.mode == .tasks {
                Button("Today") { withAnimation { model.goToday() } }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("todayButton")
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    model.searchOpen.toggle()
                    if !model.searchOpen { model.searchText = "" }
                }
            } label: {
                Image(systemName: model.searchOpen ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 34, height: 34)
            }
            .accessibilityIdentifier("searchButton")
            .accessibilityLabel("Search")
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func title(_ cal: Calendar) -> AttributedString {
        if model.mode == .tasks {
            var t = AttributedString("Tasks"); t.font = .system(size: 26, weight: .bold); return t
        }
        var month = AttributedString(DateText.monthName(model.selectedDate, calendar: cal))
        month.font = .system(size: 26, weight: .bold)
        var year = AttributedString(" " + DateText.year(model.selectedDate, calendar: cal))
        year.font = .system(size: 26, weight: .regular)
        year.foregroundColor = Theme.ink2
        return month + year
    }
}

struct SearchField: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.ink3)
            TextField("Search events and tasks", text: $model.searchText)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityIdentifier("searchField")
            if !model.searchText.isEmpty {
                Button { model.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ink3)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 11))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .onAppear { focused = true }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct AccessBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daybook needs access to Calendars and Reminders").font(.subheadline.weight(.semibold))
            Text("Turn it on in Settings › Daybook. Daybook shows your iCloud, Google and Outlook calendars.")
                .font(.footnote).foregroundStyle(Theme.ink2)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14))
        .padding(12)
    }
}

struct MonthStrip: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let cal = model.calendar
        let months = DateMath.monthStrip(around: model.selectedDate, before: 12, after: 12, calendar: cal)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(months, id: \.self) { m in
                        let shown = cal.isDate(m, equalTo: model.selectedDate, toGranularity: .month)
                        let current = cal.isDate(m, equalTo: Date(), toGranularity: .month)
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if model.mode != .month { model.mode = .month }
                                model.select(m)
                            }
                        } label: {
                            Text(DateText.monthName(m, calendar: cal, short: true))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(shown ? .white : (current ? Theme.accent : Theme.ink2))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(shown ? Theme.accent : .clear))
                        }
                        .id(m)
                    }
                }
                .padding(.horizontal, 8)
            }
            .onAppear { proxy.scrollTo(months[12], anchor: .center) }
            .onChange(of: model.selectedDate) { _, _ in
                withAnimation { proxy.scrollTo(DateMath.monthStrip(around: model.selectedDate, before: 0, after: 0, calendar: cal)[0], anchor: .center) }
            }
        }
        .frame(height: 50)
        .padding(.bottom, 26)
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthStrip")
    }
}
