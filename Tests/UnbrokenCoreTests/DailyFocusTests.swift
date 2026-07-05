import Foundation
import Testing
@testable import UnbrokenCore

@MainActor
@Suite("Daily focus — Today's 3")
struct DailyFocusTests {
    let cal = Calendar.current

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("UnbrokenFocusTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("store.json", isDirectory: false)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return cal.date(from: comps)!
    }

    private var asOf: Date { date(2026, 7, 2, 12, 0) }

    @Test("setFocus stores and focusItems reads back the same day's items")
    func setAndGet() {
        let store = HabitStore(fileURL: tempURL())
        store.setFocus([
            FocusItem(text: "Ship it", done: true),
            FocusItem(text: "Call mum", done: false),
        ], asOf: asOf)

        let items = store.focusItems(asOf: asOf)
        #expect(items.count == 2)
        #expect(items[0].text == "Ship it")
        #expect(items[0].done)
        #expect(items[1].text == "Call mum")
        #expect(!items[1].done)
    }

    @Test("text is trimmed and an empty task can never be marked done")
    func trimAndGuard() {
        let store = HabitStore(fileURL: tempURL())
        store.setFocus([
            FocusItem(text: "  padded  ", done: false),
            FocusItem(text: "   ", done: true), // blank but flagged done
        ], asOf: asOf)

        let items = store.focusItems(asOf: asOf)
        #expect(items[0].text == "padded")
        #expect(items[1].text.isEmpty)
        #expect(!items[1].done) // the guard cleared it
    }

    @Test("blank middle slot is preserved so a later checked item keeps its place")
    func preservesPositions() {
        let store = HabitStore(fileURL: tempURL())
        store.setFocus([
            FocusItem(text: "", done: false),
            FocusItem(text: "Second", done: true),
            FocusItem(text: "Third", done: false),
        ], asOf: asOf)

        let items = store.focusItems(asOf: asOf)
        #expect(items.count == 3)
        #expect(items[0].text.isEmpty)
        #expect(items[1].text == "Second")
        #expect(items[1].done)
    }

    @Test("a day with no text at all is dropped entirely")
    func allBlankPruned() {
        let store = HabitStore(fileURL: tempURL())
        store.setFocus([FocusItem(text: "temp", done: false)], asOf: asOf)
        #expect(!store.focus.isEmpty)

        store.setFocus([
            FocusItem(text: "  ", done: false),
            FocusItem(text: "", done: true),
        ], asOf: asOf)
        #expect(store.focus.isEmpty)
        #expect(store.focusItems(asOf: asOf).isEmpty)
    }

    @Test("never stores more than three items")
    func capsAtThree() {
        let store = HabitStore(fileURL: tempURL())
        store.setFocus([
            FocusItem(text: "one"), FocusItem(text: "two"),
            FocusItem(text: "three"), FocusItem(text: "four"),
        ], asOf: asOf)
        #expect(store.focusItems(asOf: asOf).count == 3)
    }

    @Test("focus is keyed per logical day — a different day reads empty")
    func perDay() {
        let store = HabitStore(fileURL: tempURL())
        store.setFocus([FocusItem(text: "Tuesday task")], asOf: asOf)

        let nextDay = date(2026, 7, 3, 12, 0)
        #expect(store.focusItems(asOf: nextDay).isEmpty)
        #expect(store.focusItems(asOf: asOf).first?.text == "Tuesday task")
    }

    @Test("a 1:30 AM check still edits the previous calendar day's list (3 AM boundary)")
    func logicalDayBoundary() {
        let store = HabitStore(fileURL: tempURL())
        store.setFocus([FocusItem(text: "late night")], asOf: date(2026, 7, 3, 1, 30))
        // 1:30 AM on the 3rd belongs to the 2nd's logical day.
        #expect(store.focusItems(asOf: date(2026, 7, 2, 22, 0)).first?.text == "late night")
    }

    @Test("focus survives a reload from disk")
    func persistsAcrossReload() {
        let url = tempURL()
        let store = HabitStore(fileURL: url)
        store.setFocus([
            FocusItem(text: "persist me", done: true),
            FocusItem(text: "and me", done: false),
        ], asOf: asOf)

        let reopened = HabitStore(fileURL: url)
        let items = reopened.focusItems(asOf: asOf)
        #expect(items.count == 2)
        #expect(items[0].text == "persist me")
        #expect(items[0].done)
    }

    @Test("a store file written before focus existed still loads (focus defaults empty)")
    func backwardCompatibleDecode() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // A pre-focus document: habits/entries/settings only, no `focus` key.
        let legacy = """
        {
          "habits": [],
          "entries": [],
          "settings": { "dayEndHour": 3, "atRiskWindowHours": 4 }
        }
        """
        try legacy.write(to: url, atomically: true, encoding: .utf8)

        let store = HabitStore(fileURL: url)
        #expect(store.focus.isEmpty)
        #expect(store.focusItems(asOf: asOf).isEmpty)
        // And it can still take a new focus list and persist normally.
        store.setFocus([FocusItem(text: "works")], asOf: asOf)
        #expect(store.focusItems(asOf: asOf).first?.text == "works")
    }
}
