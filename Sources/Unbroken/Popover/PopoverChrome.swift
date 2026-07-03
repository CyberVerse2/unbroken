import SwiftUI
import UnbrokenCore

// Small shared chrome: the pill icon buttons in headers, the accent primary
// button, and a couple of date helpers the screens share.

/// A round-pill icon button (back, gear) — soft `#F3E7D6` fill, ink glyph.
struct PillIconButton: View {
    let systemName: String
    let action: () -> Void
    var accessibilityLabel: String = ""

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.backButton))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel.isEmpty ? systemName : accessibilityLabel)
    }
}

/// Full-width accent (or habit-colored) primary button.
struct PrimaryButton: View {
    let title: String
    var fill: Color = Theme.accent
    var textColor: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.text(15, .semibold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Wraps content in a vertical `ScrollView` in the real popover (fixed-height
/// panel), but renders it as a plain column when `scrolls` is false — the
/// preview harness needs that because `ImageRenderer` won't rasterize a
/// `ScrollView`'s content.
struct MaybeScroll<Content: View>: View {
    let scrolls: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if scrolls {
            ScrollView(.vertical, showsIndicators: false) { content() }
        } else {
            content()
        }
    }
}

/// Shared date helpers so every screen speaks the same calendar.
enum FlameDates {
    static let calendar = Calendar.current

    /// "THURSDAY, JULY 3" — the dashboard's uppercase date line.
    static func headerDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased()
    }

    /// The seven logical days of the week containing `today`, starting on
    /// `firstWeekday` (1 = Sunday, 2 = Monday).
    static func weekDays(containing today: Date, firstWeekday: Int) -> [Date] {
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
