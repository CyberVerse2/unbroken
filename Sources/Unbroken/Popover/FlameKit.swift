import SwiftUI
import UnbrokenCore

// Shared building blocks for the flame popover: motion, heat tinting, the
// check controls, and the contribution/heat grids. Everything warm-cream,
// per-habit colored, and gated on Reduce Motion where it plays.

// MARK: - Metrics

/// Read-only, engine-truthful numbers for one habit. Never invents streak math —
/// current/best come straight from `store.stats`; consistency is total entries
/// over logical days lived, clamped 0–100.
@MainActor
struct HabitMetrics {
    let store: HabitStore
    let habit: Habit
    let now: Date
    private let calendar = Calendar.current

    var stats: StreakStats { store.stats(for: habit, asOf: now) }

    /// Every entry ever logged for this habit (each is one logical day).
    var totalDays: Int { store.entries.filter { $0.habitID == habit.id }.count }

    /// Logical day the habit was created on.
    var createdDay: Date { store.settings.logicalDay(containing: habit.createdAt, calendar: calendar) }

    /// Today's logical day.
    var today: Date { store.settings.logicalDay(containing: now, calendar: calendar) }

    /// Inclusive count of logical days the habit has existed (min 1).
    var daysLived: Int {
        let days = calendar.dateComponents([.day], from: createdDay, to: today).day ?? 0
        return max(days + 1, 1)
    }

    /// total ÷ days lived, as a whole percent clamped 0–100.
    var consistency: Int {
        let raw = Double(totalDays) / Double(daysLived) * 100
        return min(100, max(0, Int(raw.rounded())))
    }

    func isCompleted(on day: Date) -> Bool { store.isCompleted(habit, onLogicalDay: day) }
}

// MARK: - Heat tinting

extension Color {
    /// Contribution/heat cell fill for a completion "level": 0 = empty track,
    /// 1–4 = this color at 0.30 / 0.52 / 0.76 / 1.0. Daily habits are binary, so
    /// callers pass 0 (missed) or 4 (done); the mid levels back the legend.
    func heat(_ level: Int) -> Color {
        switch level {
        case 1: return opacity(0.30)
        case 2: return opacity(0.52)
        case 3: return opacity(0.76)
        case 4...: return self
        default: return Theme.emptyCell
        }
    }
}

// MARK: - Motion

/// Scale bounce 1 → 1.4 → 0.9 → 1 whenever `trigger` flips. Skipped under
/// Reduce Motion.
struct FlamePop: ViewModifier {
    var trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.4, duration: 0.12)
                    CubicKeyframe(0.9, duration: 0.12)
                    CubicKeyframe(1.0, duration: 0.18)
                }
            }
        }
    }
}

/// Gentle vertical float for the big flames. Skipped under Reduce Motion.
struct Floaty: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .offset(y: lifted ? -6 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.9).repeatForever(autoreverses: true),
                value: lifted
            )
            .onAppear { if !reduceMotion { lifted = true } }
    }
}

extension View {
    func flamePop(on trigger: Bool) -> some View { modifier(FlamePop(trigger: trigger)) }
    func floaty() -> some View { modifier(Floaty()) }
}

// MARK: - Check controls

/// The dashboard row's circular toggle. Unchecked: white with a warm dashed-tone
/// border. Checked: filled habit color with a white check, popping on tap.
struct FlameCheckButton: View {
    let color: Color
    let isOn: Bool
    var popTrigger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isOn ? color : Color.white)
                    .overlay(
                        Circle().strokeBorder(
                            isOn ? Color.clear : Theme.dashedBorder,
                            lineWidth: 1.6
                        )
                    )
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 38, height: 38)
            .flamePop(on: popTrigger)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Done today" : "Not done today")
    }
}

// MARK: - Mini grid (dashboard row)

/// Fourteen 8pt cells (2 rows × 7): the last two weeks, oldest top-left, today
/// bottom-right. Done cells wear the habit color; misses the empty track.
struct MiniGrid: View {
    let color: Color
    /// Completion for the last 14 logical days, index 0 = 13 days ago … 13 = today.
    let done: [Bool]

    var body: some View {
        VStack(spacing: 2.5) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 2.5) {
                    ForEach(0..<7, id: \.self) { col in
                        let i = row * 7 + col
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(done.indices.contains(i) && done[i] ? color : Theme.emptyCell)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}

// MARK: - Contribution grid (detail)

/// GitHub-style 18-week grid: 7 rows (weekday) × ~18 columns (weeks), scrolls
/// horizontally, with a Less→More legend below.
struct ContributionGrid: View {
    let color: Color
    let today: Date
    let firstWeekday: Int
    /// Scroll horizontally in the app; render flat for the preview harness
    /// (ImageRenderer won't rasterize a ScrollView's content).
    var scrolls: Bool = true
    /// Returns whether the habit was completed on a given logical day.
    let isDone: (Date) -> Bool

    private let calendar = Calendar.current
    private let weeks = 18

    private var startSunday: Date {
        // Align the grid's first column to the week containing (today - 17 weeks).
        let back = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: today) ?? today
        let weekday = calendar.component(.weekday, from: back) // 1 = Sun
        let offset = (weekday - firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: back) ?? back
    }

    private func date(week: Int, row: Int) -> Date {
        calendar.date(byAdding: .day, value: week * 7 + row, to: startSunday) ?? startSunday
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if scrolls {
                ScrollView(.horizontal, showsIndicators: false) { grid }
            } else {
                grid
            }
            legend
        }
    }

    private var grid: some View {
        HStack(spacing: 3) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { row in
                        let d = date(week: week, row: row)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(cellColor(d))
                            .frame(width: 11, height: 11)
                    }
                }
            }
        }
    }

    private func cellColor(_ d: Date) -> Color {
        if d > today { return .clear }
        return isDone(d) ? color : Theme.emptyCell
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text("Less").font(Theme.text(9.5)).foregroundStyle(Theme.inkFaint)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(color.heat(level))
                    .frame(width: 10, height: 10)
            }
            Text("More").font(Theme.text(9.5)).foregroundStyle(Theme.inkFaint)
        }
    }
}
