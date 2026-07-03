import AppKit
import SwiftUI
import UnbrokenCore

/// The menu bar icon — the product's core surface.
///
/// The whole app hangs off one always-visible glyph, so these drawings do the
/// heavy lifting: at 18pt in a translucent menu bar they have to be told apart
/// at a glance, in both light and dark appearances. Everything is drawn
/// programmatically (NSBezierPath) so it stays crisp at any backing scale — no
/// asset catalogs, no PNGs.
///
/// ## Motif — the streak flame
/// A single upward teardrop **flame** carries all five states — the same fire
/// motif the rest of the flame design speaks (🔥). The flame is "your streak,
/// still burning":
///
/// - ``IconState/noHabits``   faint flame outline    — no fire lit yet
/// - ``IconState/untouched``  hollow flame outline    — the day is open, unstarted
/// - ``IconState/partial``    flame filling from base — some done, the fire building
/// - ``IconState/allDone``    a full, solid flame     — complete, calm, satisfied
/// - ``IconState/atRisk``     a hot orange flame       — the streak is about to gutter out
///
/// ## Template vs colour — the one deliberate exception
/// Menu-bar glyphs are conventionally *template* images: AppKit tints them to
/// the bar's ink (near-black on a light bar, near-white on a dark bar) and
/// inverts them on click. That's exactly right for four of the five states, so
/// noHabits / untouched / partial / allDone all stay template and read as a
/// monochrome flame in either appearance — "done" is distinguished by being a
/// *filled* flame, not by colour.
///
/// Only ``IconState/atRisk`` opts out of template rendering, so it can burn
/// `systemOrange`. Per the product thesis the icon *is* the product and its
/// late-in-the-day colour pop is the nudge that pulls the user back — a
/// monochrome-tinted "at risk" would blend into the bar and defeat the point.
/// Orange stays legible on both light and dark bars, so the alarm reads
/// regardless. (Note the design brief also imagines allDone as orange; a
/// coloured "done" glyph would break the light/dark tinting contract and blur
/// into the alarm state, so orange is reserved for the single state that must
/// interrupt you.)
public enum MenuBarIcon {

    // MARK: - Geometry
    //
    // A 18pt canvas is the sweet spot for a modern (~22pt tall) menu bar. The
    // flame is stroked/filled, not rasterized, so it reads fine anywhere in the
    // 16–22pt range. The flame's bounding box keeps ~2pt of clear space to the
    // canvas edge so neighbouring menu-bar items never crowd the glyph.

    /// Native drawing size, in points. Rendered per-scale, so it stays sharp.
    public static let canvasSide: CGFloat = 18

    /// Bounding box of the flame within the canvas (y-up AppKit coordinates:
    /// base sits low, tip points up). 11×14 leaves ~3.5pt side / ~2pt top-bottom.
    private static let flameRect = CGRect(x: 3.5, y: 2, width: 11, height: 14)

    // MARK: - Public API

    /// A menu-bar-ready image for `state`.
    ///
    /// For ``IconState/partial`` this uses a sensible default progress of 0.5
    /// (a visibly half-filled flame) since the caller hasn't supplied a fraction.
    /// Use ``image(for:progress:)`` to reflect the real done/total ratio.
    public static func image(for state: IconState) -> NSImage {
        image(for: state, progress: 0.5)
    }

    /// A menu-bar-ready image for `state`, with `progress` (0...1) controlling
    /// how far ``IconState/partial`` has filled from the base. `progress` is
    /// ignored by every other state.
    public static func image(for state: IconState, progress: Double) -> NSImage {
        let clamped = min(max(progress, 0), 1)

        // NSImage's drawing-handler is re-invoked for every representation the
        // system needs (1x, 2x, …), which is exactly what keeps the vector
        // artwork crisp on any display.
        let image = NSImage(size: NSSize(width: canvasSide, height: canvasSide),
                            flipped: false) { _ in
            draw(state: state, progress: clamped)
            return true
        }

        // Template images let AppKit tint the glyph to match the menu bar and
        // invert it on click. atRisk opts out so it can burn systemOrange (see
        // the type doc). Every other state stays template.
        image.isTemplate = (state != .atRisk)
        image.accessibilityDescription = accessibilityDescription(for: state)
        return image
    }

    // MARK: - SwiftUI wrapper

    /// SwiftUI view wrapping ``MenuBarIcon`` for use as a `MenuBarExtra` label.
    public struct MenuBarIconView: View {
        private let state: IconState
        private let progress: Double

        /// - Parameters:
        ///   - state: which icon state to render.
        ///   - progress: base fill fraction for `.partial` (0...1). Defaults to 0.5.
        public init(state: IconState, progress: Double = 0.5) {
            self.state = state
            self.progress = progress
        }

        public var body: some View {
            Image(nsImage: MenuBarIcon.image(for: state, progress: progress))
        }
    }

    // MARK: - Drawing

    private static func draw(state: IconState, progress: Double) {
        switch state {
        case .noHabits:  drawQuietFlame()
        case .untouched: drawOutlineFlame()
        case .partial:   drawFillingFlame(progress: progress)
        case .allDone:   drawSolidFlame()
        case .atRisk:    drawHotFlame()
        }
    }

    /// noHabits — a faint flame outline. No fire lit yet: the glyph is present
    /// but quiet, unmistakably "empty / off" versus the confident hollow flame
    /// of an active-but-untouched day.
    private static func drawQuietFlame() {
        let path = flamePath()
        path.lineWidth = 1.4
        path.lineJoinStyle = .round
        NSColor.black.withAlphaComponent(0.32).setStroke()
        path.stroke()
    }

    /// untouched — a clean, confident flame outline. The day is open, the fire
    /// laid but not yet lit.
    private static func drawOutlineFlame() {
        let path = flamePath()
        path.lineWidth = 1.7
        path.lineJoinStyle = .round
        NSColor.black.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }

    /// partial — the flame outline with its lower `progress` fraction filled
    /// solid, as if the fire is catching from the base up. The filled base vs.
    /// open top reads as "some done, more to go" and distinguishes it from the
    /// uniform untouched outline.
    private static func drawFillingFlame(progress: Double) {
        let path = flamePath()

        if progress > 0 {
            NSGraphicsContext.saveGraphicsState()
            let clip = flamePath()
            clip.addClip()
            let fillHeight = flameRect.height * CGFloat(progress)
            let fillRect = CGRect(x: 0, y: flameRect.minY, width: canvasSide, height: fillHeight)
            NSColor.black.withAlphaComponent(0.9).setFill()
            NSBezierPath(rect: fillRect).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        path.lineWidth = 1.7
        path.lineJoinStyle = .round
        NSColor.black.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }

    /// allDone — a fully solid flame. Complete, calm, satisfied: the one state
    /// with a filled interior, so "done" is obvious and restful rather than loud.
    private static func drawSolidFlame() {
        let path = flamePath()
        NSColor.black.setFill()
        path.fill()
    }

    /// atRisk — a solid flame in systemOrange (see the template opt-out note in
    /// the type doc). The one moment the glyph shouts: the streak is guttering.
    private static func drawHotFlame() {
        let path = flamePath()
        NSColor.systemOrange.setFill()
        path.fill()
    }

    // MARK: - Helpers

    /// A stylized fire within ``flameRect`` (y-up: base low, tip high).
    ///
    /// The silhouette is deliberately flame-shaped, not a teardrop: the tip
    /// hooks over to the right like a licking tongue, the right flank bulges out
    /// low, and the left flank carries a pronounced concave notch — the "lick" —
    /// so it reads as fire, not a water drop, even as a flat 18pt monochrome
    /// glyph. A small kick at the base keeps the bottom from reading as a round
    /// droplet.
    private static func flamePath() -> NSBezierPath {
        let r = flameRect
        func px(_ fx: CGFloat) -> CGFloat { r.minX + fx * r.width }
        func py(_ fy: CGFloat) -> CGFloat { r.minY + fy * r.height }

        let p = NSBezierPath()
        // Tip: a SHARP point, leaning right — the single strongest "fire" cue.
        // The two curves meeting here approach from opposite sides so the join is
        // a cusp (a point), not a rounded dome like a water drop.
        p.move(to: CGPoint(x: px(0.58), y: py(1.0)))
        // Right flank: bulge out to the widest point, low on the body.
        p.curve(to: CGPoint(x: px(0.86), y: py(0.30)),
                controlPoint1: CGPoint(x: px(0.64), y: py(0.86)),
                controlPoint2: CGPoint(x: px(0.93), y: py(0.56)))
        // Round the base from the right to center-bottom.
        p.curve(to: CGPoint(x: px(0.48), y: py(0.0)),
                controlPoint1: CGPoint(x: px(0.82), y: py(0.07)),
                controlPoint2: CGPoint(x: px(0.66), y: py(0.0)))
        // Base to the lower-left shoulder.
        p.curve(to: CGPoint(x: px(0.13), y: py(0.32)),
                controlPoint1: CGPoint(x: px(0.30), y: py(0.0)),
                controlPoint2: CGPoint(x: px(0.09), y: py(0.10)))
        // THE LICK: the left flank scoops inward (concave) — the classic flame
        // notch that a teardrop never has.
        p.curve(to: CGPoint(x: px(0.46), y: py(0.52)),
                controlPoint1: CGPoint(x: px(0.19), y: py(0.46)),
                controlPoint2: CGPoint(x: px(0.45), y: py(0.39)))
        // Up from the notch, curling to the sharp leaning tip.
        p.curve(to: CGPoint(x: px(0.58), y: py(1.0)),
                controlPoint1: CGPoint(x: px(0.40), y: py(0.72)),
                controlPoint2: CGPoint(x: px(0.40), y: py(0.92)))
        p.close()
        return p
    }

    private static func accessibilityDescription(for state: IconState) -> String {
        switch state {
        case .noHabits:  return "Unbroken: no habits yet"
        case .untouched: return "Unbroken: nothing checked in today"
        case .partial:   return "Unbroken: some habits done today"
        case .allDone:   return "Unbroken: all habits done today"
        case .atRisk:    return "Unbroken: streak at risk — habits still due"
        }
    }
}
