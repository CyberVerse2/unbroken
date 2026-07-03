import AppKit
import SwiftUI
import UnbrokenCore

/// The flame design's visual language, in one place. Warm cream-on-peach,
/// Bricolage Grotesque for display + Hanken Grotesk for text, orange accent,
/// per-habit color. Every view pulls from here so the app reads as one system.
///
/// Design source: Unbroken.dc.html (claude.ai/design project "Design Unbroken app").
enum Theme {
    // MARK: Surfaces
    static let card = Color(hex: "#FFFBF4")          // popover / card fill
    static let cardRaised = Color.white              // inner rows/tiles
    static let backButton = Color(hex: "#F3E7D6")    // pill icon buttons

    // MARK: Ink
    static let ink = Color(hex: "#2A211B")           // primary text
    static let inkSoft = Color(hex: "#8A7B6E")       // secondary
    static let inkMuted = Color(hex: "#9A8A7B")      // tertiary
    static let inkFaint = Color(hex: "#B0A091")      // labels / captions
    static let inkFainter = Color(hex: "#A8977F")    // dashed add, hints

    // MARK: Lines & tracks
    static let hairline = Color(hex: "#F3EADF")      // 1px card outline
    static let divider = Color(hex: "#F1E7D9")
    static let fieldBorder = Color(hex: "#ECDFCC")
    static let dashedBorder = Color(hex: "#E4D5C0")
    static let emptyCell = Color(hex: "#F1E7D9")     // contribution grid level 0

    // MARK: Accent
    static let accent = Color(hex: "#F26B21")        // default brand orange
    static let accentWarm = Color(hex: "#F5A623")    // gradient partner

    /// The app-wide warm wallpaper behind the popover (used in window chrome
    /// and the preview harness; the real popover sits on the system panel).
    static let wallpaper = LinearGradient(
        colors: [Color(hex: "#F3C98B"), Color(hex: "#EBA277"), Color(hex: "#C97A6B")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // MARK: Fonts
    // Registered at launch by FontLoader; fall back to system if unavailable.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        Font.custom("Bricolage Grotesque", size: size).weight(weight)
    }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("Hanken Grotesk", size: size).weight(weight)
    }
}

extension Color {
    /// `#RRGGBB` (or `#RRGGBBAA`) → Color. Invalid strings fall back to the
    /// habit-palette default so a bad stored value never crashes a view.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        default:
            self = Color(hex: HabitPalette.default)
            return
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// This color at a given opacity, as a solid Color (design uses hexA()).
    func at(_ opacity: Double) -> Color { self.opacity(opacity) }
}

extension Habit {
    /// The habit's accent as a SwiftUI Color.
    var color: Color { Color(hex: colorHex) }
}
