import Foundation

/// How often a habit is meant to be done. NOTE: v3 stores this as metadata and
/// the create/edit UI lets you pick it, but the streak engine still treats every
/// habit as strict-daily. True weekday/3×-week streak math is a deferred engine
/// change — `frequency` is currently cosmetic.
public enum HabitFrequency: String, Codable, Sendable, CaseIterable {
    case daily
    case weekdays
    case threePerWeek

    public var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .threePerWeek: return "3× / week"
        }
    }
}

/// The design's habit accent palette (warm, per-habit color).
public enum HabitPalette {
    public static let colors = ["#E2603A", "#E0A32E", "#4FA96A", "#2FA39A", "#3E7BC4", "#8B5C8F"]
    public static let `default` = "#E2603A"
}

/// A habit the user is keeping a streak on.
public struct Habit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var emoji: String
    public var createdAt: Date
    public var sortOrder: Int
    /// Per-habit accent color as a `#RRGGBB` hex string.
    public var colorHex: String
    /// Intended cadence (currently cosmetic — see `HabitFrequency`).
    public var frequency: HabitFrequency

    public init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        createdAt: Date,
        sortOrder: Int,
        colorHex: String = HabitPalette.default,
        frequency: HabitFrequency = .daily
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.colorHex = colorHex
        self.frequency = frequency
    }

    // Hand-written decoding so stores written before v3 (no color/frequency)
    // still load — missing keys fall back to defaults instead of failing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decode(String.self, forKey: .emoji)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? HabitPalette.default
        frequency = try c.decodeIfPresent(HabitFrequency.self, forKey: .frequency) ?? .daily
    }
}

/// Where a check-in came from. Streak logic must never branch on this — every
/// source feeds the same entries. This is what makes "for anything" real.
public enum EntrySource: String, Codable, Sendable {
    case manual
    case cli
    case shortcuts
}

/// One check-in. `day` is the *logical* day the entry counts for, normalized
/// to start-of-day in the user's calendar (see `DaySettings.logicalDay`).
public struct Entry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var habitID: UUID
    public var day: Date
    public var source: EntrySource
    public var timestamp: Date

    public init(id: UUID = UUID(), habitID: UUID, day: Date, source: EntrySource, timestamp: Date) {
        self.id = id
        self.habitID = habitID
        self.day = day
        self.source = source
        self.timestamp = timestamp
    }
}

/// One of the day's "most important things" — a tiny daily to-do, kept apart
/// from habits and their streaks. The streak engine never sees these; they exist
/// so the user can jot the three things that actually matter today and tick them
/// off. They reset each logical day (see `DailyFocus`).
public struct FocusItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var done: Bool

    public init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}

/// The user's top tasks for a single logical day. `day` is a start-of-logical-day
/// key (see `DaySettings.logicalDay`). Stored per day so the list is blank each
/// morning while past days stay on record.
public struct DailyFocus: Codable, Hashable, Sendable {
    public var day: Date
    public var items: [FocusItem]

    public init(day: Date, items: [FocusItem]) {
        self.day = day
        self.items = items
    }

    /// True when the user wrote at least one task and finished every task they
    /// wrote. Blank slots (kept to preserve positions) don't count against you —
    /// clearing your two real items still clears the day. This is the unit the
    /// focus streak is built from.
    public var isCleared: Bool {
        let written = items.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !written.isEmpty && written.allSatisfy { $0.done }
    }
}

/// User-tunable day semantics.
public struct DaySettings: Codable, Sendable, Equatable {
    /// Hour (0–23) at which the logical day ends. Default 3: a 12:30 AM
    /// check-in still counts for "yesterday's" calendar date.
    public var dayEndHour: Int
    /// Hours before day-end during which incomplete habits are "at risk".
    public var atRiskWindowHours: Int

    public init(dayEndHour: Int = 3, atRiskWindowHours: Int = 4) {
        self.dayEndHour = dayEndHour
        self.atRiskWindowHours = atRiskWindowHours
    }

    /// The logical day containing `date`, as a start-of-day Date key.
    /// E.g. with dayEndHour 3, 2026-07-02 01:30 → 2026-07-01 00:00.
    public func logicalDay(containing date: Date, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        // Wall-clock moment `dayEndHour` on the same calendar day. Built from
        // date components (not raw second arithmetic) so DST shifts are honored.
        let boundary = boundaryHour(onDayStarting: startOfToday, calendar: calendar)
        if date < boundary {
            // Belongs to the previous calendar day's logical span.
            return calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        }
        return startOfToday
    }

    /// The wall-clock moment the given logical day ends.
    public func end(ofLogicalDay day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return boundaryHour(onDayStarting: nextDayStart, calendar: calendar)
    }

    /// `dayEndHour` o'clock on the calendar day that begins at `dayStart`,
    /// computed via date components so DST transitions are handled correctly.
    private func boundaryHour(onDayStarting dayStart: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: dayStart)
        comps.hour = dayEndHour
        comps.minute = 0
        comps.second = 0
        if let boundary = calendar.date(from: comps) {
            return boundary
        }
        // Fallback: add the hours as a calendar quantity (still not raw 86400).
        return calendar.date(byAdding: .hour, value: dayEndHour, to: dayStart) ?? dayStart
    }
}

/// Streak numbers for one habit.
public struct StreakStats: Sendable, Equatable {
    public var current: Int
    public var best: Int
    /// Logical day of the most recent entry, if any.
    public var lastCompletedDay: Date?

    public init(current: Int, best: Int, lastCompletedDay: Date?) {
        self.current = current
        self.best = best
        self.lastCompletedDay = lastCompletedDay
    }
}

/// The menu bar icon's state — the product's core surface.
public enum IconState: String, Sendable, CaseIterable {
    /// No habits configured (first run).
    case noHabits
    /// Habits exist, none checked in today.
    case untouched
    /// Some but not all checked in today.
    case partial
    /// Everything done today.
    case allDone
    /// Not all done AND the logical day ends within `atRiskWindowHours`.
    case atRisk
}
