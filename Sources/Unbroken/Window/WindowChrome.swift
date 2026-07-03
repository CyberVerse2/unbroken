import SwiftUI
import UnbrokenCore

/// Shared warm-flame chrome for the main window: the surfaces it floats on, the
/// flame mark, and the per-habit check button. Everything the window paints
/// pulls its colour and type from ``Theme`` so the window reads as the same
/// system as the popover and widget.
enum WindowStyle {
    /// The subtle warm ground the cream cards float on (a touch peachier than
    /// the cards, so cards lift off it).
    static let ground = LinearGradient(
        colors: [Color(hex: "#FCF6EC"), Color(hex: "#F5E7D3")],
        startPoint: .top, endPoint: .bottom
    )
    /// The left rail — a slightly warmer cream than the cards.
    static let sidebar = Color(hex: "#FBF2E4")
}

/// A stylized upward streak-flame (teardrop pointing up), the flame design's
/// core motif rendered as a `Shape` so it can be filled, stroked, or masked
/// anywhere in the window. SwiftUI coordinates (y grows down): tip at the top,
/// rounded base at the bottom.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        func px(_ fx: CGFloat) -> CGFloat { rect.minX + fx * rect.width }
        func py(_ fy: CGFloat) -> CGFloat { rect.minY + fy * rect.height }

        var p = Path()
        // An asymmetric flame: the tip leans right and the upper-left shoulder
        // scoops inward (a concave "lick"), so it reads as fire — not a
        // symmetric water droplet — even in flat monochrome.
        p.move(to: CGPoint(x: px(0.58), y: py(0.0)))             // tip (leaning right)
        p.addCurve(to: CGPoint(x: px(0.88), y: py(0.66)),       // right shoulder → widest
                   control1: CGPoint(x: px(0.66), y: py(0.10)),
                   control2: CGPoint(x: px(0.93), y: py(0.42)))
        p.addCurve(to: CGPoint(x: px(0.50), y: py(1.0)),        // widest → base
                   control1: CGPoint(x: px(0.86), y: py(0.90)),
                   control2: CGPoint(x: px(0.70), y: py(1.0)))
        p.addCurve(to: CGPoint(x: px(0.12), y: py(0.66)),       // base → left widest
                   control1: CGPoint(x: px(0.30), y: py(1.0)),
                   control2: CGPoint(x: px(0.10), y: py(0.90)))
        p.addCurve(to: CGPoint(x: px(0.58), y: py(0.0)),        // concave lick → tip
                   control1: CGPoint(x: px(0.14), y: py(0.42)),
                   control2: CGPoint(x: px(0.34), y: py(0.26)))
        p.closeSubpath()
        return p
    }
}

/// The window's ambient flame mark: a flame that fills from its base by the
/// day's completion, in the brand accent. Quiet (outline only) when nothing's
/// done, fully lit when the day is complete. Drawn in a `Canvas` so it renders
/// faithfully to PNG in the preview harness.
struct WindowFlame: View {
    let done: Int
    let total: Int
    var size: CGFloat = 26

    private var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }
    private var flameColor: Color {
        progress > 0 ? Theme.accent : Theme.inkFaint
    }

    var body: some View {
        Canvas { ctx, canvas in
            let rect = CGRect(origin: .zero, size: canvas)
            let path = FlameShape().path(in: rect)

            // Faint full flame behind, so the silhouette always reads.
            ctx.fill(path, with: .color(Theme.emptyCell))

            if progress > 0 {
                var clipped = ctx
                clipped.clip(to: path)
                let h = canvas.height * progress
                let fill = Path(CGRect(x: 0, y: canvas.height - h, width: canvas.width, height: h))
                clipped.fill(fill, with: .linearGradient(
                    Gradient(colors: [Theme.accentWarm, Theme.accent]),
                    startPoint: CGPoint(x: 0, y: canvas.height),
                    endPoint: CGPoint(x: 0, y: 0)
                ))
            }

            ctx.stroke(path, with: .color(flameColor.opacity(0.9)), lineWidth: 1.4)
        }
        .frame(width: size, height: size)
    }
}

/// The per-habit check-in control in the window: a soft circle that fills with
/// the habit's colour and shows a white check when today is done. Off is a
/// clean white tile with a warm dashed-ish border — an unlit spark waiting.
struct HabitCheckButton: View {
    let isOn: Bool
    let color: Color
    var diameter: CGFloat = 38
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isOn ? AnyShapeStyle(color) : AnyShapeStyle(Theme.cardRaised))
                Circle()
                    .strokeBorder(
                        isOn ? color : (hovering ? color.opacity(0.55) : Theme.dashedBorder),
                        lineWidth: 1.6
                    )
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.42, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isOn ? 1 : 0)
                    .scaleEffect(isOn ? 1 : 0.4)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.snappy(duration: 0.22), value: isOn)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityLabel(isOn ? "Checked in" : "Not checked in")
        .accessibilityAddTraits(.isButton)
    }
}
