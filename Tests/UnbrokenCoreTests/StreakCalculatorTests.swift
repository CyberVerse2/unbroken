import Foundation
import Testing
@testable import UnbrokenCore

@Suite("StreakCalculator strict daily streaks")
struct StreakCalculatorTests {
    let cal = TestClock.utcCalendar()
    let settings = DaySettings(dayEndHour: 3)

    private func habit() -> Habit {
        Habit(name: "Read", emoji: "📖", createdAt: TestClock.date(2026, 1, 1, calendar: cal), sortOrder: 0)
    }

    /// Builds an entry whose logical day is derived from `moment`.
    private func entry(_ habit: Habit, at moment: Date) -> Entry {
        Entry(
            habitID: habit.id,
            day: settings.logicalDay(containing: moment, calendar: cal),
            source: .manual,
            timestamp: moment
        )
    }

    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TestClock.date(year, month, day, 12, 0, calendar: cal)
    }

    @Test("No entries yields a zero streak")
    func emptyHistory() {
        let h = habit()
        let stats = StreakCalculator.stats(for: h, entries: [], asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 0)
        #expect(stats.best == 0)
        #expect(stats.lastCompletedDay == nil)
    }

    @Test("Today done extends an unbroken streak including today")
    func todayDone() {
        let h = habit()
        let entries = [
            entry(h, at: noon(2026, 6, 30)),
            entry(h, at: noon(2026, 7, 1)),
            entry(h, at: noon(2026, 7, 2)),
        ]
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 3)
        #expect(stats.best == 3)
        #expect(stats.lastCompletedDay == TestClock.date(2026, 7, 2, calendar: cal))
    }

    @Test("Missing today does not kill the streak while yesterday is done")
    func todayNotOverYet() {
        let h = habit()
        let entries = [
            entry(h, at: noon(2026, 6, 30)),
            entry(h, at: noon(2026, 7, 1)),
        ]
        // asOf is 2026-07-02 (logical day), today not yet checked in.
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 2)
        #expect(stats.best == 2)
        #expect(stats.lastCompletedDay == TestClock.date(2026, 7, 1, calendar: cal))
    }

    @Test("Missing both yesterday and today breaks the current streak")
    func brokenStreak() {
        let h = habit()
        let entries = [entry(h, at: noon(2026, 6, 30))]
        // asOf 2026-07-02: yesterday (07-01) and today (07-02) both missing.
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 0)
        #expect(stats.best == 1)
        #expect(stats.lastCompletedDay == TestClock.date(2026, 6, 30, calendar: cal))
    }

    @Test("Streak restarts today after a missed yesterday")
    func restartToday() {
        let h = habit()
        let entries = [
            entry(h, at: noon(2026, 6, 30)),
            // 07-01 missed
            entry(h, at: noon(2026, 7, 2)),
        ]
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 1)
        #expect(stats.best == 1)
    }

    @Test("Best streak scans all history, independent of the current run")
    func bestFromHistory() {
        let h = habit()
        let entries = [
            entry(h, at: noon(2026, 6, 1)),
            entry(h, at: noon(2026, 6, 2)),
            entry(h, at: noon(2026, 6, 3)),
            entry(h, at: noon(2026, 6, 4)), // run of 4
            entry(h, at: noon(2026, 7, 1)),
            entry(h, at: noon(2026, 7, 2)), // run of 2 (current)
        ]
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 2)
        #expect(stats.best == 4)
    }

    @Test("Multiple entries on one logical day are deduped")
    func dedupeSameDay() {
        let h = habit()
        let entries = [
            entry(h, at: TestClock.date(2026, 7, 1, 8, 0, calendar: cal)),
            entry(h, at: TestClock.date(2026, 7, 1, 20, 0, calendar: cal)),
            entry(h, at: TestClock.date(2026, 7, 2, 9, 0, calendar: cal)),
            entry(h, at: TestClock.date(2026, 7, 2, 10, 0, calendar: cal)),
        ]
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 2)
        #expect(stats.best == 2)
    }

    @Test("Entries for other habits are ignored")
    func otherHabitsIgnored() {
        let h = habit()
        let other = Habit(name: "Gym", emoji: "🏋️", createdAt: TestClock.date(2026, 1, 1, calendar: cal), sortOrder: 1)
        let entries = [
            entry(h, at: noon(2026, 7, 2)),
            Entry(habitID: other.id, day: settings.logicalDay(containing: noon(2026, 7, 1), calendar: cal), source: .manual, timestamp: noon(2026, 7, 1)),
        ]
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 2), settings: settings, calendar: cal)
        #expect(stats.current == 1)
        #expect(stats.best == 1)
    }

    @Test("An early-morning check-in counts toward the prior logical day's streak")
    func earlyMorningCheckIn() {
        let h = habit()
        // 2026-07-02 01:30 is logical day 2026-07-01 under dayEndHour 3.
        let entries = [
            entry(h, at: noon(2026, 6, 30)),
            entry(h, at: TestClock.date(2026, 7, 2, 1, 30, calendar: cal)),
        ]
        // asOf still 2026-07-01 12:00 (logical day 07-01).
        let stats = StreakCalculator.stats(for: h, entries: entries, asOf: noon(2026, 7, 1), settings: settings, calendar: cal)
        #expect(stats.current == 2)
        #expect(stats.lastCompletedDay == TestClock.date(2026, 7, 1, calendar: cal))
    }
}
