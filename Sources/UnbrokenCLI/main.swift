// `unbroken` — command-line entry source for the Unbroken habit tracker.
//
// Zero dependencies, plain argument parsing. Writes check-ins through the same
// shared HabitStore the menu bar app uses (source: .cli), so a `unbroken done`
// in a terminal lights up the menu bar icon live. This is the first external
// EntrySource — what makes "for anything" real.
//
// Usage:
//   unbroken [list]            list habits with today's status and streaks
//   unbroken done <habit>      check in today   (--yesterday to backfill)
//   unbroken undo <habit>      undo today's check-in
//   unbroken status            one-line summary for scripts/prompts
//
// <habit> matches by case-insensitive name prefix, exact (case-insensitive)
// name, or exact emoji. Exit codes: 0 ok, 1 no match / not-all-done, 2 usage
// or ambiguous match.

import Foundation
import UnbrokenCore

// A file named `main.swift` runs as top-level code on the main thread, so we're
// already on the main actor's thread — assumeIsolated lets us touch the
// @MainActor HabitStore without an async context.
let status = MainActor.assumeIsolated {
    UnbrokenCLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
}
exit(status)

// MARK: - Command dispatch

enum UnbrokenCLI {
    @MainActor
    static func run(arguments: [String]) -> Int32 {
        var args = arguments
        let command = args.first.map { $0.lowercased() } ?? "list"

        switch command {
        case "list", "ls":
            return list()
        case "done", "do", "check":
            args.removeFirst()
            return done(args)
        case "undo", "uncheck":
            args.removeFirst()
            return undo(args)
        case "status":
            return statusLine()
        case "help", "-h", "--help":
            printUsage(to: .standardOutput)
            return 0
        default:
            // No known verb → treat the whole thing as `list` only if empty,
            // otherwise it's a usage error.
            fail("unknown command '\(command)'")
            printUsage(to: .standardError)
            return 2
        }
    }

    // MARK: list

    @MainActor
    static func list() -> Int32 {
        let store = HabitStore(fileURL: nil)
        let habits = sortedHabits(store)
        guard !habits.isEmpty else {
            print("No habits yet. Add one in the Unbroken menu bar app.")
            return 0
        }
        let today = store.settings.logicalDay(containing: .now)
        let nameWidth = habits.map { displayName($0).count }.max() ?? 0

        for habit in habits {
            let done = store.isCompleted(habit, onLogicalDay: today)
            let glyph = done ? "●" : "○"
            let stats = store.stats(for: habit)
            let name = pad(displayName(habit), to: nameWidth)
            let current = stats.current > 0 ? "🔥\(stats.current)" : "·"
            print("\(glyph) \(name)   \(pad(current, to: 5)) best \(stats.best)")
        }
        return 0
    }

    // MARK: done

    @MainActor
    static func done(_ args: [String]) -> Int32 {
        var backfill = false
        let query = takeQuery(args, flags: ["--yesterday": { backfill = true }])
        guard let query else {
            fail("usage: unbroken done <habit> [--yesterday]")
            return 2
        }

        let store = HabitStore(fileURL: nil)
        switch resolve(query, in: sortedHabits(store)) {
        case .one(let habit):
            let day = backfill
                ? Calendar.current.date(byAdding: .day, value: -1, to: .now)
                : nil
            store.checkIn(habit, day: day, source: .cli)
            let stats = store.stats(for: habit)
            let when = backfill ? " (yesterday)" : ""
            let flame = stats.current > 0 ? " · 🔥\(stats.current)" : ""
            print("● \(displayName(habit)) — checked in\(when)\(flame)")
            return 0
        case .none:
            noMatch(query, in: store)
            return 1
        case .ambiguous(let candidates):
            ambiguous(query, candidates)
            return 2
        }
    }

    // MARK: undo

    @MainActor
    static func undo(_ args: [String]) -> Int32 {
        let query = takeQuery(args, flags: [:])
        guard let query else {
            fail("usage: unbroken undo <habit>")
            return 2
        }

        let store = HabitStore(fileURL: nil)
        switch resolve(query, in: sortedHabits(store)) {
        case .one(let habit):
            let today = store.settings.logicalDay(containing: .now)
            guard store.isCompleted(habit, onLogicalDay: today) else {
                print("○ \(displayName(habit)) — wasn't checked in today")
                return 0
            }
            store.undoCheckIn(habit)
            print("○ \(displayName(habit)) — check-in undone")
            return 0
        case .none:
            noMatch(query, in: store)
            return 1
        case .ambiguous(let candidates):
            ambiguous(query, candidates)
            return 2
        }
    }

    // MARK: status

    /// One tight line for prompts/scripts. Exit 0 only when everything is done.
    @MainActor
    static func statusLine() -> Int32 {
        let store = HabitStore(fileURL: nil)
        let habits = store.habits
        let state = store.iconState()

        guard !habits.isEmpty else {
            print("no habits")
            return 1
        }

        let today = store.settings.logicalDay(containing: .now)
        let doneCount = habits.filter { store.isCompleted($0, onLogicalDay: today) }.count
        let line = "\(doneCount)/\(habits.count) done"

        switch state {
        case .allDone:
            print("\(line) ✓")
            return 0
        case .atRisk:
            print("\(line) · at risk")
            return 1
        case .partial, .untouched, .noHabits:
            print(line)
            return 1
        }
    }

    // MARK: - Habit resolution

    enum Match {
        case one(Habit)
        case none
        case ambiguous([Habit])
    }

    /// Match order: exact emoji → exact (case-insensitive) name → name prefix.
    /// An exact name wins over a prefix so "read" beats "reading" unambiguously.
    static func resolve(_ rawQuery: String, in habits: [Habit]) -> Match {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)

        // Emoji comparison ignores the variation selector (U+FE0F) so "🏋" and
        // "🏋️" match, and normalizes so equal glyphs compare equal.
        let queryEmoji = normalizeEmoji(query)
        let emojiMatches = habits.filter { normalizeEmoji($0.emoji) == queryEmoji }
        if emojiMatches.count == 1 { return .one(emojiMatches[0]) }

        let lower = query.lowercased()
        let exact = habits.filter { $0.name.lowercased() == lower }
        if exact.count == 1 { return .one(exact[0]) }

        let prefix = habits.filter { $0.name.lowercased().hasPrefix(lower) }
        switch prefix.count {
        case 0: return .none
        case 1: return .one(prefix[0])
        default: return .ambiguous(prefix)
        }
    }

    // MARK: - Helpers

    @MainActor
    static func sortedHabits(_ store: HabitStore) -> [Habit] {
        store.habits.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func displayName(_ habit: Habit) -> String {
        habit.emoji.isEmpty ? habit.name : "\(habit.emoji) \(habit.name)"
    }

    /// Right-pad to `width` grapheme clusters. Uses `.count` (not
    /// `padding(toLength:)`, which counts UTF-16 units and would truncate emoji).
    static func pad(_ string: String, to width: Int) -> String {
        let deficit = width - string.count
        return deficit > 0 ? string + String(repeating: " ", count: deficit) : string
    }

    /// Strip the emoji variation selector and canonicalize for robust matching.
    static func normalizeEmoji(_ string: String) -> String {
        string.replacingOccurrences(of: "\u{FE0F}", with: "").precomposedStringWithCanonicalMapping
    }

    /// Pull the first non-flag argument as the habit query, invoking a handler
    /// for each recognized flag along the way.
    static func takeQuery(_ args: [String], flags: [String: () -> Void]) -> String? {
        var query: String?
        for arg in args {
            if let handler = flags[arg] {
                handler()
            } else if !arg.hasPrefix("-"), query == nil {
                query = arg
            }
        }
        return query
    }

    @MainActor
    static func noMatch(_ query: String, in store: HabitStore) {
        fail("no habit matches '\(query)'")
        let names = sortedHabits(store).map { displayName($0) }
        if !names.isEmpty {
            fail("known habits: \(names.joined(separator: ", "))")
        }
    }

    static func ambiguous(_ query: String, _ candidates: [Habit]) {
        fail("'\(query)' is ambiguous — matches:")
        for habit in candidates {
            fail("  \(displayName(habit))")
        }
    }

    static func printUsage(to handle: OutputTarget) {
        let usage = """
        unbroken — command-line check-ins for the Unbroken habit tracker

          unbroken [list]         list habits, today's status, and streaks
          unbroken done <habit>   check in today   (--yesterday to backfill)
          unbroken undo <habit>   undo today's check-in
          unbroken status         one-line summary (exit 0 when all done)

        <habit> matches by name prefix, exact name, or emoji.
        """
        switch handle {
        case .standardOutput: print(usage)
        case .standardError: FileHandle.standardError.write(Data((usage + "\n").utf8))
        }
    }

    enum OutputTarget { case standardOutput, standardError }

    /// Write an error line to stderr.
    static func fail(_ message: String) {
        FileHandle.standardError.write(Data(("unbroken: " + message + "\n").utf8))
    }
}
