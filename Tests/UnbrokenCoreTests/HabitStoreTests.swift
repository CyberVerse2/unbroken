import Foundation
import Testing
@testable import UnbrokenCore

@MainActor
@Suite("HabitStore CRUD, check-ins, and persistence")
struct HabitStoreTests {
    // HabitStore uses Calendar.current internally, so tests mirror that.
    let cal = Calendar.current

    /// A unique temp file URL so each test is isolated.
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("UnbrokenTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("store.json", isDirectory: false)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return cal.date(from: comps)!
    }

    private var asOf: Date { date(2026, 7, 2, 12, 0) } // safely mid-day

    // MARK: CRUD

    @Test("addHabit assigns increasing sort orders and persists")
    func addHabit() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        let b = store.addHabit(name: "Gym", emoji: "🏋️")
        #expect(store.habits.count == 2)
        #expect(a.sortOrder == 0)
        #expect(b.sortOrder == 1)
    }

    @Test("rename updates name and emoji")
    func rename() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        store.rename(a, to: "Read more", emoji: "📚")
        #expect(store.habits.first?.name == "Read more")
        #expect(store.habits.first?.emoji == "📚")
    }

    @Test("delete removes the habit and its entries")
    func deleteRemovesEntries() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        let b = store.addHabit(name: "Gym", emoji: "🏋️")
        store.checkIn(a, asOf: asOf)
        store.checkIn(b, asOf: asOf)
        store.delete(a)
        #expect(store.habits.count == 1)
        #expect(store.entries.allSatisfy { $0.habitID == b.id })
    }

    // MARK: Check-ins

    @Test("checkIn today marks completion")
    func checkInToday() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        store.checkIn(a, asOf: asOf)
        let today = store.settings.logicalDay(containing: asOf, calendar: cal)
        #expect(store.isCompleted(a, onLogicalDay: today))
        #expect(store.entries.count == 1)
    }

    @Test("Double check-in on the same day is idempotent")
    func doubleCheckInIsNoOp() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        store.checkIn(a, asOf: asOf)
        store.checkIn(a, asOf: asOf)
        #expect(store.entries.filter { $0.habitID == a.id }.count == 1)
    }

    @Test("Backfill yesterday is accepted")
    func backfillYesterdayAccepted() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        let yesterday = cal.date(byAdding: .day, value: -1, to: asOf)!
        store.checkIn(a, day: yesterday, asOf: asOf)
        let yesterdayLogical = cal.date(byAdding: .day, value: -1, to: store.settings.logicalDay(containing: asOf, calendar: cal))!
        #expect(store.isCompleted(a, onLogicalDay: yesterdayLogical))
        #expect(store.entries.count == 1)
    }

    @Test("Backfill older than yesterday is a silent no-op")
    func backfillOlderRejected() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: asOf)!
        store.checkIn(a, day: threeDaysAgo, asOf: asOf)
        #expect(store.entries.isEmpty)
    }

    @Test("Future days are rejected")
    func futureRejected() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        let tomorrow = cal.date(byAdding: .day, value: 1, to: asOf)!
        store.checkIn(a, day: tomorrow, asOf: asOf)
        #expect(store.entries.isEmpty)
    }

    @Test("undoCheckIn removes today's entry")
    func undoRemoves() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        store.checkIn(a, asOf: asOf)
        #expect(store.entries.count == 1)
        store.undoCheckIn(a, asOf: asOf)
        #expect(store.entries.isEmpty)
    }

    @Test("undoCheckIn on a day with no entry is a no-op")
    func undoNothing() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        store.undoCheckIn(a, asOf: asOf)
        #expect(store.entries.isEmpty)
    }

    // MARK: Persistence

    @Test("State round-trips through a temp-dir file URL")
    func persistenceRoundTrip() {
        let url = tempURL()
        var settingsCopy = DaySettings()

        do {
            let store = HabitStore(fileURL: url)
            let a = store.addHabit(name: "Read", emoji: "📖")
            _ = store.addHabit(name: "Gym", emoji: "🏋️")
            store.checkIn(a, asOf: asOf)
            store.settings = DaySettings(dayEndHour: 5, atRiskWindowHours: 2)
            settingsCopy = store.settings
        }

        let reloaded = HabitStore(fileURL: url)
        #expect(reloaded.habits.count == 2)
        #expect(reloaded.habits.map(\.name) == ["Read", "Gym"])
        #expect(reloaded.entries.count == 1)
        #expect(reloaded.settings == settingsCopy)
        #expect(reloaded.settings.dayEndHour == 5)
    }

    @Test("A fresh store with no file starts empty")
    func freshStoreEmpty() {
        let store = HabitStore(fileURL: tempURL())
        #expect(store.habits.isEmpty)
        #expect(store.entries.isEmpty)
        #expect(store.settings == DaySettings())
    }

    @Test("stats and iconState surface derived values")
    func derivedHelpers() {
        let store = HabitStore(fileURL: tempURL())
        let a = store.addHabit(name: "Read", emoji: "📖")
        store.checkIn(a, asOf: asOf)
        #expect(store.stats(for: a, asOf: asOf).current == 1)
        #expect(store.iconState(asOf: asOf) == .allDone)
    }
}
