import Foundation
import Testing
@testable import UnbrokenCore

// Tests added by the CLI / live-reload work: moveHabits ordering semantics,
// Snapshot round-tripping, and cross-instance external-change reload.
@MainActor
@Suite("moveHabits, snapshot, and external-change reload")
struct ExternalChangeAndMoveTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("UnbrokenReloadTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("store.json", isDirectory: false)
    }

    /// Add habits named A, B, C, … and return the store, seeded and ordered.
    private func makeStore(_ names: [String]) -> HabitStore {
        let store = HabitStore(fileURL: tempURL())
        for name in names { _ = store.addHabit(name: name, emoji: "") }
        return store
    }

    /// Current order as a list of names, sorted by sortOrder (the persisted order).
    private func order(_ store: HabitStore) -> [String] {
        store.habits.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
    }

    // MARK: moveHabits — SwiftUI onMove semantics (pre-removal destination)

    @Test("move first → last")
    func moveFirstToLast() {
        let store = makeStore(["A", "B", "C", "D"])
        store.moveHabits(fromOffsets: IndexSet(integer: 0), toOffset: 4)
        #expect(order(store) == ["B", "C", "D", "A"])
    }

    @Test("move last → first")
    func moveLastToFirst() {
        let store = makeStore(["A", "B", "C", "D"])
        store.moveHabits(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(order(store) == ["D", "A", "B", "C"])
    }

    @Test("move a middle item")
    func moveMiddle() {
        let store = makeStore(["A", "B", "C", "D"])
        // Move B (offset 1) to sit before pre-removal index 3.
        store.moveHabits(fromOffsets: IndexSet(integer: 1), toOffset: 3)
        #expect(order(store) == ["A", "C", "B", "D"])
    }

    @Test("move an IndexSet with multiple offsets")
    func moveMultiple() {
        let store = makeStore(["A", "B", "C", "D"])
        // Move A and C (offsets 0 and 2) to the end.
        store.moveHabits(fromOffsets: IndexSet([0, 2]), toOffset: 4)
        #expect(order(store) == ["B", "D", "A", "C"])
    }

    @Test("moveHabits persists the new order to disk")
    func movePersists() {
        let url = tempURL()
        do {
            let store = HabitStore(fileURL: url)
            for name in ["A", "B", "C"] { _ = store.addHabit(name: name, emoji: "") }
            store.moveHabits(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        }
        let reloaded = HabitStore(fileURL: url)
        #expect(order(reloaded) == ["B", "C", "A"])
    }

    // MARK: Snapshot

    @Test("snapshot round-trips habits, entries, and settings")
    func snapshotRoundTrip() {
        let url = tempURL()
        let store = HabitStore(fileURL: url)
        let a = store.addHabit(name: "Read", emoji: "📖")
        _ = store.addHabit(name: "Gym", emoji: "🏋️")
        store.checkIn(a, asOf: .now)
        store.settings = DaySettings(dayEndHour: 5, atRiskWindowHours: 2)

        let snapshot = HabitStore.snapshot(at: url)
        #expect(snapshot != nil)
        #expect(snapshot?.habits.count == 2)
        #expect(snapshot?.entries.count == 1)
        #expect(snapshot?.settings == DaySettings(dayEndHour: 5, atRiskWindowHours: 2))
    }

    @Test("snapshot of a missing file is nil")
    func snapshotMissingIsNil() {
        #expect(HabitStore.snapshot(at: tempURL()) == nil)
    }

    // MARK: External-change reload (cross-instance, live)

    @Test("an external write is picked up by a watching instance", .timeLimit(.minutes(1)))
    func externalWriteReloads() async {
        let url = tempURL()

        // Instance A creates the store and seeds one habit.
        let a = HabitStore(fileURL: url)
        _ = a.addHabit(name: "Read", emoji: "📖")

        // Instance B loads the same file and begins watching for outside changes.
        let b = HabitStore(fileURL: url)
        #expect(b.habits.count == 1)
        b.startWatchingForExternalChanges()
        b.startWatchingForExternalChanges() // idempotent — must not double-watch

        // A mutates the shared file from "another process".
        _ = a.addHabit(name: "Gym", emoji: "🏋️")

        // B should observe the new habit within a generous window.
        let sawGym = await poll(timeout: 10) { b.habits.count == 2 }
        #expect(sawGym)
        #expect(b.habits.contains { $0.name == "Gym" })
    }

    @Test("a watching instance ignores its own writes (no reload loop)")
    func ownWritesDoNotLoop() async {
        let url = tempURL()
        let store = HabitStore(fileURL: url)
        _ = store.addHabit(name: "Read", emoji: "📖")
        store.startWatchingForExternalChanges()

        // Drive several of our own saves; the content-differs guard must keep
        // the state consistent (no duplicate/dropped habits from a reload storm).
        for name in ["Gym", "Meditate", "Walk"] {
            _ = store.addHabit(name: name, emoji: "")
        }
        // Give any (unwanted) reload tasks time to fire.
        _ = await poll(timeout: 1) { false }
        #expect(store.habits.count == 4)
        #expect(Set(store.habits.map(\.name)) == ["Read", "Gym", "Meditate", "Walk"])
    }

    /// Poll `condition` on the main actor until true or the timeout elapses,
    /// yielding the actor between checks so background reload tasks can run.
    private func poll(timeout seconds: Double, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }
}
