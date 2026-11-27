import SwiftUI

struct SwipeAction {
    let title: String
    let icon: String
    let color: Color
    /// Slide the row off screen before running the action (for delete).
    var removes = false
    let run: () -> Void
}

/// Swipe a row sideways to reveal an action; let go past the threshold to run it.
/// Works inside a ScrollView: the drag only takes over once it is clearly horizontal.
struct SwipeActions: ViewModifier {
    var leading: SwipeAction?
    var trailing: SwipeAction?

    @State private var offset: CGFloat = 0
    @State private var horizontal: Bool?
    @State private var armed = false
    @State private var width: CGFloat = 400
    private let threshold: CGFloat = 90

    func body(content: Content) -> some View {
        content
            .background(Theme.bg)
            .offset(x: offset)
            .background { revealed }
            .background(GeometryReader { g in Color.clear.onAppear { width = g.size.width } })
            .clipped()
            .simultaneousGesture(drag)
            .accessibilityActions {
                if let a = leading { Button(a.title) { a.run() } }
                if let a = trailing { Button(a.title) { a.run() } }
            }
    }

    @ViewBuilder private var revealed: some View {
        let action = offset > 0 ? leading : (offset < 0 ? trailing : nil)
        if let action {
            HStack(spacing: 8) {
                if offset < 0 { Spacer(minLength: 0) }
                Image(systemName: action.icon).font(.system(size: 17, weight: .semibold))
                    .scaleEffect(armed ? 1.15 : 0.9)
                Text(action.title).font(.system(size: 14, weight: .semibold))
                if offset > 0 { Spacer(minLength: 0) }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(armed ? action.color : action.color.opacity(0.55))
            .animation(.easeOut(duration: 0.12), value: armed)
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                if horizontal == nil {
                    horizontal = abs(v.translation.width) > abs(v.translation.height) * 1.3
                }
                guard horizontal == true else { return }
                var x = v.translation.width
                if x > 0 && leading == nil { x = 0 }
                if x < 0 && trailing == nil { x = 0 }
                offset = x
                let nowArmed = abs(x) > threshold
                if nowArmed != armed {
                    armed = nowArmed
                    if nowArmed { Haptics.tick() }
                }
            }
            .onEnded { v in
                defer { horizontal = nil; armed = false }
                guard horizontal == true else { return }
                let x = offset
                let action = x > threshold ? leading : (x < -threshold ? trailing : nil)
                if let action {
                    if action.removes {
                        withAnimation(.easeIn(duration: 0.2)) { offset = x > 0 ? width : -width }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            action.run()
                            offset = 0
                        }
                    } else {
                        action.run()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                }
            }
    }
}

extension View {
    func rowSwipe(leading: SwipeAction? = nil, trailing: SwipeAction? = nil) -> some View {
        modifier(SwipeActions(leading: leading, trailing: trailing))
    }
}
