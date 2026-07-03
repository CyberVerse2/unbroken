import AppKit
import SwiftUI
import UnbrokenCore

/// A GitHub-contributions-style history of a habit: 7 rows (days of the week) ×
/// N week-columns, the rightmost column being the current, still-open week.
///
/// A filled cell is a completed logical day, burning the habit's own colour; an
/// empty day is the warm level-0 grid cell (`Theme.emptyCell`). Today wears a
/// thin outline — the accent orange when the streak is at risk, otherwise the
/// habit colour. All day math goes through the calendar; never raw seconds.
struct HistoryGridView: View {
    let store: HabitStore
    let habit: Habit
    /// The current logical day (start-of-day key), from DaySettings.logicalDay.
    let today: Date
    /// True when today isn't done yet and the day-end window is closing.
    let isTodayAtRisk: Bool

    var weeks: Int = 26
    var cell: CGFloat = 12
    var gap: CGFloat = 3

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            monthLabels
            HStack(alignment: .top, spacing: gap) {
                ForEach(columns) { column in
                    VStack(spacing: gap) {
                        ForEach(column.days) { slot in
                            cellView(for: slot)
                        }
                    }
                }
            }
        }
    }

    // MARK: Cell

    @ViewBuilder
    private func cellView(for slot: DaySlot) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        switch slot.kind {
        case .future:
            // Beyond today: keep the grid rectangular but read as "not yet".
            shape.fill(Theme.emptyCell.opacity(0.5))
                .frame(width: cell, height: cell)
        case .day(let date, let completed):
            let isToday = calendar.isDate(date, inSameDayAs: today)
            // A completed day burns the habit's own colour (level 4); an empty
            // one stays the warm level-0 grid cell.
            shape
                .fill(completed ? habit.color : Theme.emptyCell)
                .frame(width: cell, height: cell)
                .overlay {
                    if isToday {
                        shape.strokeBorder(
                            isTodayAtRisk ? Theme.accent : habit.color.opacity(0.5),
                            lineWidth: 1.5
                        )
                    }
                }
        }
    }

    // MARK: Month labels

    /// Month labels sit above the column where each month begins and are allowed
    /// to overflow to the right (like GitHub's), so short labels never wrap.
    private var monthLabels: some View {
        let pitch = cell + gap
        let gridWidth = CGFloat(weeks) * cell + CGFloat(weeks - 1) * gap
        // Allow labels near the right edge to overflow rather than wrap (GitHub
        // does the same). The extra trailing slack keeps a 3-letter month on one
        // line even when its column sits at the far right.
        return ZStack(alignment: .topLeading) {
            ForEach(columns) { column in
                if let label = column.monthLabel {
                    Text(label)
                        .font(Theme.text(8.5, .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: CGFloat(column.id) * pitch)
                }
            }
        }
        .frame(width: gridWidth + 20, height: 11, alignment: .topLeading)
    }

    // MARK: Grid model

    private enum SlotKind {
        case day(date: Date, completed: Bool)
        case future
    }

    private struct DaySlot: Identifiable {
        let id: Int
        let kind: SlotKind
    }

    private struct Column: Identifiable {
        let id: Int
        let days: [DaySlot]
        let monthLabel: String?
    }

    /// Builds `weeks` columns ending with the week that contains today. Row 0 is
    /// the first weekday of the user's calendar; the last column is truncated to
    /// today (later slots become `.future`).
    private var columns: [Column] {
        // Row offset of today within its own week (0 = first weekday of week).
        let weekday = calendar.component(.weekday, from: today)
        let rowOfToday = (weekday - calendar.firstWeekday + 7) % 7
        // Sunday/Monday-of-this-week, per the calendar's firstWeekday.
        let currentWeekStart = calendar.date(byAdding: .day, value: -rowOfToday, to: today) ?? today

        var result: [Column] = []
        var lastMonth = -1
        for c in 0..<weeks {
            let weeksBack = (weeks - 1) - c
            guard let weekStart = calendar.date(byAdding: .day, value: -weeksBack * 7, to: currentWeekStart) else {
                continue
            }
            var slots: [DaySlot] = []
            for r in 0..<7 {
                let date = calendar.date(byAdding: .day, value: r, to: weekStart) ?? weekStart
                if date > today {
                    slots.append(DaySlot(id: c * 7 + r, kind: .future))
                } else {
                    let completed = store.isCompleted(habit, onLogicalDay: date)
                    slots.append(DaySlot(id: c * 7 + r, kind: .day(date: date, completed: completed)))
                }
            }
            // Show a month label the first time a new month starts a column.
            let month = calendar.component(.month, from: weekStart)
            let label: String?
            if month != lastMonth {
                lastMonth = month
                label = monthAbbrev(month)
            } else {
                label = nil
            }
            result.append(Column(id: c, days: slots, monthLabel: label))
        }
        return result
    }

    private func monthAbbrev(_ month: Int) -> String {
        let symbols = calendar.shortMonthSymbols
        guard month >= 1, month <= symbols.count else { return "" }
        return symbols[month - 1]
    }
}
