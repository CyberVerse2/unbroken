import SwiftUI
import UnbrokenCore

/// The streak flame — the menu bar glyph writ large. One flame carries every
/// ``IconState``, mirroring `MenuBarIcon` but rendered in SwiftUI so it stays
/// crisp at widget sizes and can wear real colour on the cream tile.
///
/// - noHabits   faint flame outline        — no fire lit yet
/// - untouched  ink flame outline          — the day is open, unstarted
/// - partial    flame filling from the base — some done, the fire building
/// - allDone    full accent flame + ✓       — complete, calm, satisfied
/// - atRisk     a hot orange flame          — the streak is about to gutter out
struct WidgetFlame: View {
    let state: IconState
    /// Fraction 0...1 for the `.partial` base-up fill (done / total).
    let progress: Double

    var body: some View {
        Canvas { ctx, size in
            let rect = Self.flameRect(in: size)
            let path = FlameShape().path(in: rect)
            let lw = rect.width * 0.085
            let fillGradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Brand.accentWarm, Brand.accent]),
                startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                endPoint: CGPoint(x: rect.midX, y: rect.minY)
            )

            switch state {
            case .noHabits:
                ctx.stroke(path, with: .color(Brand.inkFaint.opacity(0.7)),
                           style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            case .untouched:
                ctx.stroke(path, with: .color(Brand.inkSoft),
                           style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            case .partial:
                ctx.fill(path, with: .color(Brand.emptyCell))
                if progress > 0 {
                    var clipped = ctx
                    clipped.clip(to: path)
                    let h = rect.height * progress
                    clipped.fill(
                        Path(CGRect(x: rect.minX, y: rect.maxY - h, width: rect.width, height: h)),
                        with: fillGradient
                    )
                }
                ctx.stroke(path, with: .color(Brand.accent),
                           style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            case .allDone:
                ctx.fill(path, with: fillGradient)
            case .atRisk:
                ctx.fill(path, with: .color(Brand.orange))
            }
        }
        .overlay {
            if state == .allDone {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    Image(systemName: "checkmark")
                        .font(.system(size: side * 0.26, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: geo.size.width, height: geo.size.height * 1.08,
                               alignment: .center)
                }
            }
        }
    }

    /// An aspect-correct flame box centred in `size` (flame is ~11:14).
    private static func flameRect(in size: CGSize) -> CGRect {
        let side = min(size.width, size.height)
        let h = side * 0.94
        let w = h * (11.0 / 14.0)
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
}

/// A stylized upward streak-flame (teardrop pointing up) — the flame design's
/// core motif as a `Shape`. Widget-local copy (the app's `FlameShape` lives in a
/// different target). SwiftUI coordinates (y grows down): tip on top, base below.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        func px(_ fx: CGFloat) -> CGFloat { rect.minX + fx * rect.width }
        func py(_ fy: CGFloat) -> CGFloat { rect.minY + fy * rect.height }

        var p = Path()
        p.move(to: CGPoint(x: px(0.58), y: py(0.0)))
        p.addCurve(to: CGPoint(x: px(0.88), y: py(0.66)),
                   control1: CGPoint(x: px(0.66), y: py(0.10)),
                   control2: CGPoint(x: px(0.93), y: py(0.42)))
        p.addCurve(to: CGPoint(x: px(0.50), y: py(1.0)),
                   control1: CGPoint(x: px(0.86), y: py(0.90)),
                   control2: CGPoint(x: px(0.70), y: py(1.0)))
        p.addCurve(to: CGPoint(x: px(0.12), y: py(0.66)),
                   control1: CGPoint(x: px(0.30), y: py(1.0)),
                   control2: CGPoint(x: px(0.10), y: py(0.90)))
        p.addCurve(to: CGPoint(x: px(0.58), y: py(0.0)),
                   control1: CGPoint(x: px(0.14), y: py(0.42)),
                   control2: CGPoint(x: px(0.34), y: py(0.26)))
        p.closeSubpath()
        return p
    }
}
