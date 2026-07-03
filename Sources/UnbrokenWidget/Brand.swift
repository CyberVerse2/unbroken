import SwiftUI

/// The widget's slice of the flame design system. The widget is a separate
/// process from the app, so it can't reach the app's `Theme` — this restates the
/// same warm cream-on-flame palette and Bricolage/Hanken type here, scaled for a
/// desktop / Notification Center tile.
///
/// Unlike the menu bar glyph (a template image AppKit tints), the widget owns a
/// fixed cream tile with real estate, so it renders in full colour: cream cards,
/// per-habit hues in the list, and orange reserved for the at-risk alarm.
enum Brand {
    // MARK: Surfaces
    /// Tile background — the flame design's warm cream card fill (#FFFBF4).
    static let card = Color(hex: "#FFFBF4")
    /// A soft warm ground behind the card, for a little depth.
    static let ground = Color(hex: "#F5E7D3")
    /// Inner tiles / white chips.
    static let raised = Color.white

    // MARK: Ink
    static let ink = Color(hex: "#2A211B")
    static let inkSoft = Color(hex: "#8A7B6E")
    static let inkFaint = Color(hex: "#B0A091")
    static let emptyCell = Color(hex: "#F1E7D9")

    // MARK: Accent
    static let accent = Color(hex: "#F26B21")
    static let accentWarm = Color(hex: "#F5A623")
    /// The one alarm colour — at-risk only.
    static let orange = Color(hex: "#F26B21")

    // MARK: Fonts
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        Font.custom("Bricolage Grotesque", size: size).weight(weight)
    }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("Hanken Grotesk", size: size).weight(weight)
    }
}

extension Color {
    /// `#RRGGBB` (or `#RRGGBBAA`) → Color. Invalid strings fall back to the warm
    /// accent so a bad stored value never crashes a widget view. (A widget-local
    /// copy of the app's `Color(hex:)`, since Theme isn't reachable here.)
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
            r = 0.949; g = 0.42; b = 0.129; a = 1   // #F26B21
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
