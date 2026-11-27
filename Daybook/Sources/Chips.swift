import SwiftUI
import DaybookKit

/// The small entries drawn in month cells and all-day rows.
struct EntryChip: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let item: DayItem
    var height: CGFloat = 15
    var fontSize: CGFloat = 10.5

    var body: some View {
        switch item {
        case .timed(let e): timed(e)
        case .allDay(let e): allDay(e)
        case .task(let t): task(t)
        }
    }

    private func timed(_ e: CalEvent) -> some View {
        let c = ChipColors(hex: model.colorHex(for: e), scheme: scheme)
        return Button { model.sheet = .event(e) } label: {
            HStack(spacing: 0) {
                Rectangle().fill(c.base).frame(width: 3.5)
                Text(e.title)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(c.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 3)
                Spacer(minLength: 0)
            }
            .frame(height: height)
            .background(c.fill)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .draggable("event:\(e.id)") { DragPreview(title: e.title, color: c.base) }
        .accessibilityIdentifier("chip-\(e.title)")
    }

    private func allDay(_ e: CalEvent) -> some View {
        let c = ChipColors(hex: model.colorHex(for: e), scheme: scheme)
        return Button { model.sheet = .event(e) } label: {
            Text(e.title)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(c.text)
                .lineLimit(1)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(c.base, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .draggable("event:\(e.id)") { DragPreview(title: e.title, color: c.base) }
        .accessibilityIdentifier("chip-\(e.title)")
    }

    private func task(_ t: TaskItem) -> some View {
        let c = ChipColors(hex: model.colorHex(for: t), scheme: scheme)
        return HStack(spacing: 3) {
            CheckBox(done: t.isCompleted, color: c.base, size: height - 5) { model.toggle(t) }
                .accessibilityIdentifier("check-\(t.title)")
            Button { model.sheet = .task(t, defaultDue: nil) } label: {
                Text(t.title)
                    .font(.system(size: fontSize, weight: .medium))
                    .strikethrough(t.isCompleted)
                    .foregroundStyle(c.text)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 2)
        .frame(height: height)
        .background(c.fill.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .opacity(t.isCompleted ? 0.55 : 1)
        .draggable("task:\(t.id)") { DragPreview(title: t.title, color: c.base) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chip-\(t.title)")
    }
}

/// What follows the finger while an entry is dragged to another day.
struct DragPreview: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 18)
            Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(color, lineWidth: 1.5))
    }
}

struct CheckBox: View {
    let done: Bool
    let color: Color
    var size: CGFloat = 18
    var round: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                let shape = RoundedRectangle(cornerRadius: round ? size / 2 : size * 0.28)
                shape.stroke(color, lineWidth: max(1, size / 9))
                if done {
                    shape.fill(color)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.62, weight: .heavy))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle().inset(by: -6))
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: done)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(done ? "Mark as not done" : "Complete")
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

/// One outlined bar for a multi-day event in a week row.
struct MultiDayBar: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    let event: CalEvent
    let segment: BarSegment
    var height: CGFloat = 15

    var body: some View {
        let c = ChipColors(hex: model.colorHex(for: event), scheme: scheme)
        Button { model.sheet = .event(event) } label: {
            HStack(spacing: 2) {
                if segment.continuesBefore {
                    Image(systemName: "chevron.left").font(.system(size: 7, weight: .bold))
                }
                Text(event.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if segment.continuesAfter {
                    Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold))
                }
            }
            .foregroundStyle(c.text)
            .padding(.horizontal, 4)
            .frame(height: height)
            .background(c.fill.opacity(0.35))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(c.base, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .draggable("event:\(event.id)") { DragPreview(title: event.title, color: c.base) }
        .accessibilityIdentifier("bar-\(event.title)")
    }
}
