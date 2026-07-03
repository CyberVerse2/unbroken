import SwiftUI
import UnbrokenCore

/// One habit up close: a big flame streak counter, three stat cards, this-week
/// rings, an 18-week contribution grid, and the current month's heatmap.
struct DetailView: View {
    @Bindable var store: HabitStore
    let habit: Habit
    let clock: AppClock
    let firstWeekday: Int
    var scrolls: Bool = true
    let onBack: () -> Void
    let onOpenSettings: () -> Void
    let onEdit: () -> Void

    @State private var popTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let calendar = Calendar.current

    private var metrics: HabitMetrics { HabitMetrics(store: store, habit: habit, now: clock.now) }
    private var today: Date { store.settings.logicalDay(containing: clock.now, calendar: calendar) }
    private var isDone: Bool { store.isCompleted(habit, onLogicalDay: today) }
    private var color: Color { habit.color }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 6)

            MaybeScroll(scrolls: scrolls) {
                VStack(spacing: 22) {
                    flameBlock
                    statCards
                    weekSection
                    contributionSection
                    monthSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            PillIconButton(systemName: "chevron.left", action: onBack, accessibilityLabel: "Back")
            Spacer()
            Text("\(habit.emoji.isEmpty ? "🔥" : habit.emoji)  \(habit.name)")
                .font(Theme.display(16, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer()
            PillIconButton(systemName: "square.and.pencil", action: onEdit, accessibilityLabel: "Edit habit")
        }
    }

    // MARK: Flame counter

    private var flameBlock: some View {
        VStack(spacing: 6) {
            Text("🔥")
                .font(.system(size: 52))
                .floaty()
            Text("\(metrics.stats.current)")
                .font(Theme.display(60, .heavy))
                .foregroundStyle(color)
                .flamePop(on: popTrigger)
            Text("DAY STREAK")
                .font(Theme.text(11, .semibold))
                .kerning(1.5)
                .foregroundStyle(Theme.inkFaint)

            checkCTA.padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RadialGradient(colors: [color.opacity(0.16), color.opacity(0.0)],
                           center: .center, startRadius: 8, endRadius: 180)
        )
    }

    private var checkCTA: some View {
        Button {
            if isDone {
                store.undoCheckIn(habit, asOf: clock.now)
            } else {
                store.checkIn(habit, asOf: clock.now)
                popTrigger.toggle()
                withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                    CheckInEffects.didCheckIn(store: store, now: clock.now)
                }
            }
        } label: {
            Text(isDone ? "✓ Done today" : "Mark done today")
                .font(Theme.text(14.5, .semibold))
                .foregroundStyle(isDone ? color : Color.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isDone ? color.opacity(0.14) : color)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Stat cards

    private var statCards: some View {
        HStack(spacing: 10) {
            statCard("\(metrics.stats.best)", "Longest")
            statCard("\(metrics.consistency)%", "Consistency")
            statCard("\(metrics.totalDays)", "Total days")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.display(22, .heavy))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.text(11))
                .foregroundStyle(Theme.inkFainter)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1))
        )
    }

    // MARK: This week

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("This week")
            HStack(spacing: 0) {
                ForEach(FlameDates.weekDays(containing: today, firstWeekday: firstWeekday), id: \.self) { day in
                    let done = store.isCompleted(habit, onLogicalDay: day)
                    let isToday = calendar.isDate(day, inSameDayAs: today)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(done ? color : Color.white)
                                .overlay(Circle().strokeBorder(
                                    isToday ? color.opacity(0.5) : (done ? Color.clear : Theme.fieldBorder),
                                    lineWidth: isToday ? 2 : 1))
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 36, height: 36)
                        Text(dayLetter(day))
                            .font(Theme.text(10.5, .medium))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayLetter(_ day: Date) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let idx = calendar.component(.weekday, from: day) - 1
        return symbols.indices.contains(idx) ? symbols[idx] : ""
    }

    // MARK: Contribution grid

    private var contributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Last 18 weeks")
            ContributionGrid(
                color: color,
                today: today,
                firstWeekday: firstWeekday,
                scrolls: scrolls,
                isDone: { store.isCompleted(habit, onLogicalDay: $0) }
            )
        }
    }

    // MARK: Month heatmap

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(today.formatted(.dateTime.month(.wide).year()))
            MonthHeatmap(
                color: color,
                today: today,
                firstWeekday: firstWeekday,
                isDone: { store.isCompleted(habit, onLogicalDay: $0) }
            )
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(15, .bold))
            .foregroundStyle(Theme.ink)
    }
}

/// Current calendar month as a 7-column grid with weekday headers; each day cell
/// is tinted when the habit was completed that logical day.
private struct MonthHeatmap: View {
    let color: Color
    let today: Date
    let firstWeekday: Int
    let isDone: (Date) -> Bool

    private let calendar = Calendar.current

    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: today) else { return [] }
        let first = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let leading = (calendar.component(.weekday, from: first) - firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var headers: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { symbols[(firstWeekday - 1 + $0) % 7] }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(spacing: 7) {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(Theme.text(9.5, .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let done = isDone(day)
                        let future = day > today
                        let isToday = calendar.isDate(day, inSameDayAs: today)
                        Text("\(calendar.component(.day, from: day))")
                            .font(Theme.text(11, done ? .semibold : .regular))
                            .foregroundStyle(done ? .white : (future ? Theme.inkFaint.opacity(0.5) : Theme.inkSoft))
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(done ? color : Theme.emptyCell.opacity(future ? 0.4 : 1))
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isToday && !done ? color.opacity(0.5) : Color.clear, lineWidth: 1.5))
                            )
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
    }
}
