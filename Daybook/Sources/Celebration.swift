import SwiftUI

/// Plays once when the last open task of a day is ticked: a badge that lands with a
/// squash and stretch, and a burst of sparkles around it.
struct CelebrationOverlay: View {
    @State private var particles = Sparkle.burst(count: 18)
    @State private var startedAt = Date()
    @State private var landed = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(startedAt)
                Canvas { gc, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
                    for p in particles { p.draw(in: &gc, center: center, time: t) }
                }
            }
            badge
                .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            startedAt = Date()
            withAnimation(Theme.Motion.bouncy) { landed = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("celebration")
    }

    private var badge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: "#2fb35a"))
            Text("All done for today")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.line))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: landed) { view, y in
            view.scaleEffect(x: 1 + (1 - y) * 0.5, y: y, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.04, duration: 0.18)
                CubicKeyframe(0.92, duration: 0.2)
                CubicKeyframe(1.04, duration: 0.22)
                CubicKeyframe(0.98, duration: 0.2)
                CubicKeyframe(1, duration: 0.2)
            }
        }
        .scaleEffect(landed ? 1 : 0.4)
        .opacity(landed ? 1 : 0)
    }
}

/// One sparkle of the burst: flies out from the centre, slows, spins and fades.
struct Sparkle {
    let angle: Double
    let distance: Double
    let delay: Double
    let life: Double
    let size: Double
    let spin: Double
    let color: Color

    static let palette: [Color] = [
        Color(hex: "#2fb35a"), Color(hex: "#ffcc00"), Color(hex: "#4d82ff"), Color(hex: "#ff2d55"), Color(hex: "#ffffff")
    ]

    static func burst(count: Int) -> [Sparkle] {
        (0..<count).map { i in
            Sparkle(angle: Double(i) / Double(count) * 2 * .pi + .random(in: -0.25...0.25),
                    distance: .random(in: 90...170),
                    delay: .random(in: 0...0.4),
                    life: .random(in: 0.5...1.0),
                    size: .random(in: 5...11),
                    spin: .random(in: -3...3),
                    color: palette[i % palette.count])
        }
    }

    func draw(in gc: inout GraphicsContext, center: CGPoint, time: Double) {
        let local = (time - delay) / life
        guard local > 0, local < 1 else { return }
        let eased = 1 - pow(1 - local, 3)                 // fast out, slow at the end
        let r = distance * eased
        let dx: Double = cos(angle) * r
        let dy: Double = sin(angle) * r + 30 * local * local
        let p = CGPoint(x: Double(center.x) + dx, y: Double(center.y) + dy)
        let s = size * (1 - 0.6 * local)
        var ctx = gc
        ctx.opacity = 1 - local * local
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: .radians(spin * local))
        ctx.fill(Self.star(size: s), with: .color(color))
    }

    /// A four-point sparkle.
    static func star(size: Double) -> Path {
        var path = Path()
        let a = size, b = size * 0.28
        path.move(to: CGPoint(x: 0.0, y: -a))
        path.addQuadCurve(to: CGPoint(x: a, y: 0), control: CGPoint(x: b, y: -b))
        path.addQuadCurve(to: CGPoint(x: 0, y: a), control: CGPoint(x: b, y: b))
        path.addQuadCurve(to: CGPoint(x: -a, y: 0), control: CGPoint(x: -b, y: b))
        path.addQuadCurve(to: CGPoint(x: 0, y: -a), control: CGPoint(x: -b, y: -b))
        return path
    }
}
