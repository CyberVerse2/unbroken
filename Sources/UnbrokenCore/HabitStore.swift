import Foundation
import Observation

/// Owns the model and persists it as JSON (atomic writes) in
/// Application Support/Unbroken/store.json. No accounts, no sync.
@MainActor
@Observable
public final class HabitStore {
    public private(set) var habits: [Habit] = []
    public private(set) var entries: [Entry] = []
    public var settings: DaySettings = DaySettings() {
        didSet { save() }
    }

    /// Location of the JSON document backing this store.
    @ObservationIgnored private let fileURL: URL
    /// Suppresses `save()` while the initial document is being loaded.
    @ObservationIgnored private var isLoading = false

    /// The exact bytes this instance last wrote to (or loaded from) disk. The
    /// external-change watcher compares against this so our *own* saves never
    /// trigger a reload loop.
    @ObservationIgnored private var lastWrittenData: Data?
    /// File-system watcher on the store's *directory*. We watch the directory,
    /// not the file, because an atomic write replaces the file's inode — a
    /// watch on the old inode would go deaf after the very first external save.
    @ObservationIgnored private var watchSource: DispatchSourceFileSystemObject?
    /// Bumped on every file-system event so the debounced reload only fires for
    /// the most recent one in a burst.
    @ObservationIgnored private var watchGeneration = 0

    /// The single Codable document persisted to disk.
    private struct StoreDocument: Codable {
        var habits: [Habit]
        var entries: [Entry]
        var settings: DaySettings
    }

    /// Pass a custom URL in tests; nil uses the default App Support location.
    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? HabitStore.defaultFileURL()
        isLoading = true
        load()
        isLoading = false
    }

    /// Where the store lives by default — shared by the app, CLI, and widget
    /// (all non-sandboxed, same user domain).
    public nonisolated static var defaultStoreURL: URL { defaultFileURL() }

    private nonisolated static func defaultFileURL() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Unbroken", isDirectory: true)
            .appendingPathComponent("store.json", isDirectory: false)
    }

    // MARK: Habits

    @discardableResult
    public func addHabit(
        name: String,
        emoji: String,
        colorHex: String = HabitPalette.default,
        frequency: HabitFrequency = .daily
    ) -> Habit {
        let sortOrder = (habits.map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(
            name: name,
            emoji: emoji,
            createdAt: Date(),
            sortOrder: sortOrder,
            colorHex: colorHex,
            frequency: frequency
        )
        habits.append(habit)
        save()
        return habit
    }

    public func rename(_ habit: Habit, to name: String, emoji: String) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].name = name
        habits[index].emoji = emoji
        save()
    }

    /// Full edit — name, emoji, color, and cadence in one shot (used by the
    /// create/edit screens in the flame design).
    public func update(
        _ habit: Habit,
        name: String,
        emoji: String,
        colorHex: String,
        frequency: HabitFrequency
    ) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].name = name
        habits[index].emoji = emoji
        habits[index].colorHex = colorHex
        habits[index].frequency = frequency
        save()
    }

    public func delete(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        entries.removeAll { $0.habitID == habit.id }
        save()
    }

    // MARK: Check-ins

    /// Check in for the logical day containing `asOf`, or — backfill — for the
    /// logical day before it. Anything older is rejected (no-op).
    public func checkIn(_ habit: Habit, day: Date? = nil, asOf: Date = .now, source: EntrySource = .manual) {
        guard let target = resolveBackfillableDay(day, asOf: asOf) else { return }
        // Idempotent: never duplicate a check-in on the same logical day.
        guard !isCompleted(habit, onLogicalDay: target) else { return }
        let entry = Entry(habitID: habit.id, day: target, source: source, timestamp: asOf)
        entries.append(entry)
        save()
    }

    /// Reorder habits SwiftUI-style (matches `onMove` semantics: offsets into
    /// the sorted list, destination expressed pre-removal); rewrites `sortOrder`.
    public func moveHabits(fromOffsets: IndexSet, toOffset: Int) {
        let ordered = habits.sorted { $0.sortOrder < $1.sortOrder }
        let moving = fromOffsets.map { ordered[$0] }
        var remaining = ordered.enumerated()
            .filter { !fromOffsets.contains($0.offset) }
            .map(\.element)
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let destination = min(max(toOffset - removedBeforeDestination, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: destination)
        for (index, habit) in remaining.enumerated() {
            if let i = habits.firstIndex(where: { $0.id == habit.id }) {
                habits[i].sortOrder = index
            }
        }
        save()
    }

    public func undoCheckIn(_ habit: Habit, day: Date? = nil, asOf: Date = .now) {
        guard let target = resolveBackfillableDay(day, asOf: asOf) else { return }
        let calendar = Calendar.current
        let before = entries.count
        entries.removeAll {
            $0.habitID == habit.id && calendar.startOfDay(for: $0.day) == target
        }
        if entries.count != before { save() }
    }

    public func isCompleted(_ habit: Habit, onLogicalDay day: Date) -> Bool {
        let calendar = Calendar.current
        let key = calendar.startOfDay(for: day)
        return entries.contains {
            $0.habitID == habit.id && calendar.startOfDay(for: $0.day) == key
        }
    }

    /// Resolves the requested logical day and enforces the backfill window:
    /// only today's or yesterday's logical day is writable; older/future → nil.
    private func resolveBackfillableDay(_ day: Date?, asOf: Date) -> Date? {
        let calendar = Calendar.current
        let today = settings.logicalDay(containing: asOf, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let target = day.map { calendar.startOfDay(for: $0) } ?? today
        guard target == today || target == yesterday else { return nil }
        return target
    }

    // MARK: Derived

    public func stats(for habit: Habit, asOf: Date = .now) -> StreakStats {
        StreakCalculator.stats(for: habit, entries: entries, asOf: asOf, settings: settings)
    }

    public func iconState(asOf: Date = .now) -> IconState {
        IconStateResolver.state(habits: habits, entries: entries, asOf: asOf, settings: settings)
    }

    // MARK: Out-of-process access

    /// Read-only view of a store document for out-of-process readers
    /// (widget timelines, `unbroken status`) that must not hold the store open.
    public struct Snapshot: Sendable {
        public let habits: [Habit]
        public let entries: [Entry]
        public let settings: DaySettings
    }

    /// Decode a snapshot without constructing a live store. Returns nil if the
    /// file is missing or unreadable.
    public nonisolated static func snapshot(at url: URL? = nil) -> Snapshot? {
        let target = url ?? defaultFileURL()
        guard let data = try? Data(contentsOf: target),
              let document = try? JSONDecoder().decode(StoreDocument.self, from: data) else {
            return nil
        }
        return Snapshot(habits: document.habits, entries: document.entries, settings: document.settings)
    }

    /// Begin watching the backing file for writes made by other processes
    /// (CLI, future watchers) and reload when they land. Idempotent — calling
    /// it twice is a no-op. Safe to call before the file exists.
    public func startWatchingForExternalChanges() {
        guard watchSource == nil else { return } // already watching

        // Watch the *containing directory*: atomic writes swap the file's inode,
        // so a descriptor on the file itself would stop reporting after one save.
        // The directory must exist to be opened for watching; creating it here is
        // harmless (save() creates it anyway) and lets us watch pre-first-write.
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        // Deliver events directly on the main queue. This keeps the handler on
        // the main-actor executor, so touching @MainActor state and scheduling
        // the debounced reload is valid — dispatching events to a *private*
        // queue and then resuming a main-actor consumer trips the Swift 6
        // runtime's strict executor-isolation assertion (SIGTRAP). Events are
        // rare (only when the store file is written), so the main queue is fine.
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.fileSystemEventArrived() }
        }
        source.setCancelHandler { close(descriptor) }
        watchSource = source
        source.resume()
    }

    /// Debounce a burst of file-system events (~200ms) down to a single reload.
    /// Runs on the main actor (the source fires on the main queue).
    private func fileSystemEventArrived() {
        watchGeneration &+= 1
        let generation = watchGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, generation == self.watchGeneration else { return } // superseded
            self.reloadIfChanged()
        }
    }

    /// Reload from disk, but only when the on-disk bytes actually differ from
    /// what this instance last wrote — this is what breaks the save→watch→reload
    /// loop for our own writes. Updates the @Observable state so UI refreshes.
    private func reloadIfChanged() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if data == lastWrittenData { return } // our own write, or identical content
        guard let document = try? JSONDecoder().decode(StoreDocument.self, from: data) else { return }
        isLoading = true // guard settings.didSet from writing back
        habits = document.habits
        entries = document.entries
        settings = document.settings
        isLoading = false
        lastWrittenData = data
    }

    deinit {
        watchSource?.cancel()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let document = try? JSONDecoder().decode(StoreDocument.self, from: data) else { return }
        habits = document.habits
        entries = document.entries
        settings = document.settings
        lastWrittenData = data
    }

    private func save() {
        guard !isLoading else { return }
        let document = StoreDocument(habits: habits, entries: entries, settings: settings)
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
            lastWrittenData = data // fingerprint our own write so the watcher ignores it
        } catch {
            // Persistence is best-effort; a failed write must not crash the app.
        }
    }
}
