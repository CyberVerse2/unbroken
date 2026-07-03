import SwiftUI
import UnbrokenCore

/// A one-tap starter habit shown on the onboarding pick screen.
struct StarterHabit: Identifiable, Equatable {
    let name: String
    let emoji: String
    let colorHex: String
    var id: String { name }

    /// The four warm starters a stranger can pick without thinking.
    static let all: [StarterHabit] = [
        StarterHabit(name: "Read 20 pages", emoji: "📖", colorHex: "#3E7BC4"),
        StarterHabit(name: "Move your body", emoji: "🏃", colorHex: "#E0A32E"),
        StarterHabit(name: "Meditate", emoji: "🧘", colorHex: "#2FA39A"),
        StarterHabit(name: "Drink water", emoji: "💧", colorHex: "#3E7BC4"),
    ]
}

/// Onboarding step: pick a starter habit (one tap creates it and advances) or
/// build your own. Keeps the very first decision tiny — the whole point of the
/// app is starting, not configuring.
struct OnboardingPickHabitView: View {
    var scrolls: Bool = true
    let onPick: (StarterHabit) -> Void
    let onMakeOwn: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("🔥")
                    .font(.system(size: 40))
                    .floaty()
                    .padding(.bottom, 4)
                Text("Pick your first streak")
                    .font(Theme.display(24, .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Start with one small thing you can do today. You can add more later.")
                    .font(Theme.text(13.5))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.top, 30)
            .padding(.bottom, 20)

            MaybeScroll(scrolls: scrolls) {
                VStack(spacing: 12) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(StarterHabit.all) { starter in
                            StarterCard(starter: starter) { onPick(starter) }
                        }
                    }
                    makeOwnButton
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
    }

    private var makeOwnButton: some View {
        Button(action: onMakeOwn) {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Make my own")
                    .font(Theme.text(13.5, .medium))
            }
            .foregroundStyle(Theme.inkFainter)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Theme.dashedBorder)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A tappable starter tile: big emoji on the habit's color wash, the name below.
private struct StarterCard: View {
    let starter: StarterHabit
    let action: () -> Void

    private var color: Color { Color(hex: starter.colorHex) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(starter.emoji)
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(color.opacity(0.14))
                    )
                Text(starter.name)
                    .font(Theme.display(14.5, .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
