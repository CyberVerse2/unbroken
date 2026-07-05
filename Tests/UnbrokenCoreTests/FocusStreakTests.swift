import Foundation
import Testing
@testable import UnbrokenCore

@MainActor
@Suite("Focus streak — clearing Today's 3")
struct FocusStreakTests {
    let cal = Calendar.current
    let settings = DaySettings()

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = dayOfMonth; comps.hour = hour
        return cal.date(from: comps)!
    }

    /// A cleared DailyFocus (all written items done) keyed to the start of the
    /// logical day containing `date`.
    private func cleared(_ date: Date, count: Int = 3) -> DailyFocus {
        let key = cal.startOfDay(for: settings.logicalDay(containing: date))
        return DailyFocus(day: key, items: (0..<count).map { FocusItem(text: "task \($0)", done: true) })
    }

    private func partial(_ date: Date) -> DailyFocus {
        let key = cal.startOfDay(for: settings.logicalDay(containing: date))
        return DailyFocus(day: key, items: [
            FocusItem(text: "done", done: true),
            FocusItem(text: "not done", done: false),
        ])
    }

    @Test("consecutive cleared days build the current and best streak")
    func consecutive() {
        let today = day(2026, 7, 5)
        let focus = [cleared(day(2026, 7, 3)), cleared(day(2026, 7, 4)), cleared(today)]
        let stats = FocusStreakCalculator.stats(focus: focus, asOf: today, settings: settings)
        #expect(stats.current == 3)
        #expect(stats.best == 3)
    }

    @Test("a partly-done day is not cleared and breaks the streak")
    func partialBreaks() {
        let today = day(2026, 7, 5)
        let focus = [cleared(day(2026, 7, 3)), partial(day(2026, 7, 4)), cleared(today)]
        let stats = FocusStreakCalculator.stats(focus: focus, asOf: today, settings: settings)
        // Only today is a run; the 4th wasn't cleared.
        #expect(stats.current == 1)
        #expect(stats.best == 1)
    }

    @Test("today still pending keeps yesterday's streak alive (grace)")
    func todayGrace() {
        let today = day(2026, 7, 5)
        // Cleared through yesterday; nothing for today yet.
        let focus = [cleared(day(2026, 7, 3)), cleared(day(2026, 7, 4))]
        let stats = FocusStreakCalculator.stats(focus: focus, asOf: today, settings: settings)
        #expect(stats.current == 2) // not reset just because today isn't done yet
    }

    @Test("a gap before yesterday means no current streak")
    func brokenBeforeYesterday() {
        let today = day(2026, 7, 5)
        // Last cleared was two days ago — streak is dead.
        let focus = [cleared(day(2026, 7, 3))]
        let stats = FocusStreakCalculator.stats(focus: focus, asOf: today, settings: settings)
        #expect(stats.current == 0)
        #expect(stats.best == 1)
    }

    @Test("clearing only the real items (a blank slot) still counts")
    func blanksDontBlock() {
        let today = day(2026, 7, 5)
        let key = cal.startOfDay(for: settings.logicalDay(containing: today))
        let withBlank = DailyFocus(day: key, items: [
            FocusItem(text: "", done: false),        // blank, preserved position
            FocusItem(text: "real one", done: true),
        ])
        #expect(withBlank.isCleared)
        let stats = FocusStreakCalculator.stats(focus: [withBlank], asOf: today, settings: settings)
        #expect(stats.current == 1)
    }

    @Test("store.focusStats reflects live check-ins on today's list")
    func throughStore() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnbrokenFocusStreak-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("store.json")
        let store = HabitStore(fileURL: url)
        let today = day(2026, 7, 5)

        // Write today's three, none done yet → not cleared, no streak.
        store.setFocus([
            FocusItem(text: "a"), FocusItem(text: "b"), FocusItem(text: "c"),
        ], asOf: today)
        #expect(store.focusStats(asOf: today).current == 0)
        #expect(!store.focusClearedToday(asOf: today))

        // Finish all three → cleared, streak of 1.
        store.setFocus([
            FocusItem(text: "a", done: true),
            FocusItem(text: "b", done: true),
            FocusItem(text: "c", done: true),
        ], asOf: today)
        #expect(store.focusClearedToday(asOf: today))
        #expect(store.focusStats(asOf: today).current == 1)
    }
}
