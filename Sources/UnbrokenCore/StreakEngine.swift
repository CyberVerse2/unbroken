import Foundation

/// Pure streak math. Reads entries only — never knows where they came from.
public enum StreakCalculator {
    /// Current and best streak for one habit.
    ///
    /// Rules (v1, strict daily):
    /// - A logical day counts if it has ≥1 entry for the habit.
    /// - The current streak is unbroken if the habit was completed on the
    ///   current logical day OR the previous one (today isn't over yet —
    ///   missing *today* doesn't kill the streak until the day actually ends).
    /// - Best streak scans all history.
    public static func stats(
        for habit: Habit,
        entries: [Entry],
        asOf: Date,
        settings: DaySettings,
        calendar: Calendar = .current
    ) -> StreakStats {
        // Distinct logical days on which this habit has at least one entry.
        // `entry.day` is already the normalized logical-day key; re-normalize
        // to start-of-day defensively (never re-run logicalDay on it — that key
        // is a calendar midnight and would shift under the day-end rule).
        var days = Set<Date>()
        for entry in entries where entry.habitID == habit.id {
            days.insert(calendar.startOfDay(for: entry.day))
        }

        guard !days.isEmpty else {
            return StreakStats(current: 0, best: 0, lastCompletedDay: nil)
        }

        // Best streak: longest run of consecutive logical days in all history.
        let sorted = days.sorted()
        var best = 0
        var run = 0
        var previous: Date? = nil
        for day in sorted {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }

        // Current streak: anchor on today if done, else yesterday if done,
        // else the streak is broken (0). Count consecutive days backward.
        let currentDay = settings.logicalDay(containing: asOf, calendar: calendar)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
        let anchor: Date?
        if days.contains(currentDay) {
            anchor = currentDay
        } else if days.contains(previousDay) {
            anchor = previousDay
        } else {
            anchor = nil
        }

        var current = 0
        if var cursor = anchor {
            while days.contains(cursor) {
                current += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            }
        }

        return StreakStats(current: current, best: best, lastCompletedDay: days.max())
    }
}

/// Maps the whole model to the menu bar icon's state.
public enum IconStateResolver {
    public static func state(
        habits: [Habit],
        entries: [Entry],
        asOf: Date,
        settings: DaySettings,
        calendar: Calendar = .current
    ) -> IconState {
        guard !habits.isEmpty else { return .noHabits }

        let day = settings.logicalDay(containing: asOf, calendar: calendar)
        let completedDays = completedHabitDays(entries: entries, onLogicalDay: day, calendar: calendar)

        let completedCount = habits.reduce(into: 0) { count, habit in
            if completedDays.contains(habit.id) { count += 1 }
        }

        // Everything done wins outright — it beats at-risk.
        if completedCount == habits.count {
            return .allDone
        }

        // Not all done: at-risk if we're inside the closing window of the day.
        let end = settings.end(ofLogicalDay: day, calendar: calendar)
        let windowStart = calendar.date(byAdding: .hour, value: -settings.atRiskWindowHours, to: end) ?? end
        if asOf >= windowStart {
            return .atRisk
        }

        return completedCount == 0 ? .untouched : .partial
    }

    /// The set of habit IDs that have at least one entry on the given logical day.
    private static func completedHabitDays(
        entries: [Entry],
        onLogicalDay day: Date,
        calendar: Calendar
    ) -> Set<UUID> {
        let key = calendar.startOfDay(for: day)
        var result = Set<UUID>()
        for entry in entries where calendar.startOfDay(for: entry.day) == key {
            result.insert(entry.habitID)
        }
        return result
    }
}
