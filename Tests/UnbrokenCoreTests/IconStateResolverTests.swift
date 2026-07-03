import Foundation
import Testing
@testable import UnbrokenCore

@Suite("IconStateResolver state matrix")
struct IconStateResolverTests {
    let cal = TestClock.utcCalendar()
    let settings = DaySettings(dayEndHour: 3, atRiskWindowHours: 4)

    private func makeHabit(_ order: Int) -> Habit {
        Habit(name: "H\(order)", emoji: "✅", createdAt: TestClock.date(2026, 1, 1, calendar: cal), sortOrder: order)
    }

    private func entry(_ habit: Habit, on logicalDay: Date) -> Entry {
        Entry(habitID: habit.id, day: logicalDay, source: .manual, timestamp: logicalDay)
    }

    // Logical day 2026-07-02; ends 2026-07-03 03:00; at-risk window starts 2026-07-02 23:00.
    private var day: Date { TestClock.date(2026, 7, 2, calendar: cal) }
    private var midday: Date { TestClock.date(2026, 7, 2, 12, 0, calendar: cal) }
    private var insideRiskWindow: Date { TestClock.date(2026, 7, 3, 0, 0, calendar: cal) } // 00:00 -> still logical day 07-02

    @Test("No habits configured -> noHabits")
    func noHabits() {
        #expect(IconStateResolver.state(habits: [], entries: [], asOf: midday, settings: settings, calendar: cal) == .noHabits)
    }

    @Test("Habits exist, none done, mid-day -> untouched")
    func untouched() {
        let habits = [makeHabit(0), makeHabit(1)]
        #expect(IconStateResolver.state(habits: habits, entries: [], asOf: midday, settings: settings, calendar: cal) == .untouched)
    }

    @Test("Some but not all done, mid-day -> partial")
    func partial() {
        let habits = [makeHabit(0), makeHabit(1)]
        let entries = [entry(habits[0], on: day)]
        #expect(IconStateResolver.state(habits: habits, entries: entries, asOf: midday, settings: settings, calendar: cal) == .partial)
    }

    @Test("All done, mid-day -> allDone")
    func allDone() {
        let habits = [makeHabit(0), makeHabit(1)]
        let entries = [entry(habits[0], on: day), entry(habits[1], on: day)]
        #expect(IconStateResolver.state(habits: habits, entries: entries, asOf: midday, settings: settings, calendar: cal) == .allDone)
    }

    @Test("Untouched inside the closing window -> atRisk")
    func atRiskUntouched() {
        let habits = [makeHabit(0)]
        #expect(IconStateResolver.state(habits: habits, entries: [], asOf: insideRiskWindow, settings: settings, calendar: cal) == .atRisk)
    }

    @Test("Partial inside the closing window -> atRisk")
    func atRiskPartial() {
        let habits = [makeHabit(0), makeHabit(1)]
        let entries = [entry(habits[0], on: day)]
        #expect(IconStateResolver.state(habits: habits, entries: entries, asOf: insideRiskWindow, settings: settings, calendar: cal) == .atRisk)
    }

    @Test("All done inside the closing window -> allDone beats atRisk")
    func allDoneBeatsAtRisk() {
        let habits = [makeHabit(0), makeHabit(1)]
        let entries = [entry(habits[0], on: day), entry(habits[1], on: day)]
        #expect(IconStateResolver.state(habits: habits, entries: entries, asOf: insideRiskWindow, settings: settings, calendar: cal) == .allDone)
    }

    @Test("Exactly at the window start boundary -> atRisk")
    func atRiskBoundaryInclusive() {
        let habits = [makeHabit(0)]
        let windowStart = TestClock.date(2026, 7, 2, 23, 0, calendar: cal)
        #expect(IconStateResolver.state(habits: habits, entries: [], asOf: windowStart, settings: settings, calendar: cal) == .atRisk)
    }

    @Test("One second before the window start -> not yet atRisk")
    func justBeforeWindowIsUntouched() {
        let habits = [makeHabit(0)]
        let justBefore = TestClock.date(2026, 7, 2, 22, 59, 59, calendar: cal)
        #expect(IconStateResolver.state(habits: habits, entries: [], asOf: justBefore, settings: settings, calendar: cal) == .untouched)
    }
}
