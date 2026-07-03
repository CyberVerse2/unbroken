import AppKit
import SwiftUI
import UnbrokenCore

/// One habit as a full card in the main window: emoji + name, the streak/best/
/// total numbers, today's check-in ring, and a contributions history grid.
///
/// It's the popover row grown up — a cream card on the warm ground, with room
/// to show the shape of the streak over time. Each habit wears its own colour:
/// the emoji tile, the 🔥 streak count, the contribution grid, and the check
/// button all tint to `habit.color`.
struct HabitCardView: View {
    let store: HabitStore
    let habit: Habit
    let clock: AppClock

    let onToggle: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    private let calendar = Calendar.current

    private var today: Date {
        store.settings.logicalDay(containing: clock.now, calendar: calendar)
    }
    private var isCompletedToday: Bool {
        store.isCompleted(habit, onLogicalDay: today)
    }
    private var stats: StreakStats {
        store.stats(for: habit, asOf: clock.now)
    }
    private var totalCheckIns: Int {
        store.entries.reduce(into: 0) { $0 += ($1.habitID == habit.id ? 1 : 0) }
    }

    /// Today isn't done and the logical day ends within the at-risk window.
    private var isTodayAtRisk: Bool {
        guard !isCompletedToday else { return false }
        let end = store.settings.end(ofLogicalDay: today, calendar: calendar)
        guard let windowStart = calendar.date(
            byAdding: .hour, value: -store.settings.atRiskWindowHours, to: end
        ) else { return false }
        return clock.now >= windowStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            header
            HistoryGridView(
                store: store,
                habit: habit,
                today: today,
                isTodayAtRisk: isTodayAtRisk
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.card)
                .shadow(color: Theme.ink.opacity(hovering ? 0.08 : 0.05),
                        radius: hovering ? 9 : 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contextMenu {
            Button("Rename…", action: onRename)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            Text(habit.emoji.isEmpty ? "🔥" : habit.emoji)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(habit.color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(habit.name)
                    .font(Theme.display(15.5, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                statLine
            }

            Spacer(minLength: 8)

            HabitCheckButton(isOn: isCompletedToday, color: habit.color, diameter: 38, action: onToggle)
        }
    }

    private var statLine: some View {
        HStack(spacing: 12) {
            if stats.current > 0 {
                HStack(spacing: 4) {
                    Text("🔥").font(.system(size: 12))
                    Text("\(stats.current)")
                        .font(Theme.display(14, .bold))
                        .monospacedDigit()
                        .foregroundStyle(habit.color)
                    Text(stats.current == 1 ? "day" : "days")
                        .font(Theme.text(12, .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
            } else {
                Text(stats.best > 0 ? "streak broken" : "no streak yet")
                    .font(Theme.text(12.5, .medium))
                    .foregroundStyle(Theme.inkFaint)
            }

            statDetail(label: "best", value: "\(stats.best)")
            statDetail(label: "total", value: "\(totalCheckIns)")
        }
    }

    private func statDetail(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(Theme.text(12.5, .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSoft)
            Text(label)
                .font(Theme.text(12.5))
                .foregroundStyle(Theme.inkFaint)
        }
    }
}
