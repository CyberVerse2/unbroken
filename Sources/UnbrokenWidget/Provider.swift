import Foundation
import WidgetKit
import UnbrokenCore

/// One line in the medium widget's habit list.
struct HabitLine: Identifiable, Sendable {
    let id: UUID
    let emoji: String
    let name: String
    let done: Bool
    /// Current streak length (for the 🔥 count).
    let streak: Int
    /// Per-habit accent as a `#RRGGBB` hex string (the flame-design colour).
    let colorHex: String
}

/// A single point on the widget timeline. Because the store file doesn't change
/// under us between refreshes, the *data* is constant across an entry batch —
/// what varies is the clock: a later entry can flip `.partial` → `.atRisk` or
/// cross the 3 AM rollover into a fresh, untouched day.
struct UnbrokenEntry: TimelineEntry {
    let date: Date
    let state: IconState
    let completed: Int
    let total: Int
    let lines: [HabitLine]

    var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Placeholder shown before real data loads (redacted by the system).
    static let placeholder = UnbrokenEntry(
        date: .now, state: .partial, completed: 2, total: 4,
        lines: [
            HabitLine(id: UUID(), emoji: "📖", name: "Read",     done: true,  streak: 12, colorHex: "#3E7BC4"),
            HabitLine(id: UUID(), emoji: "🏃", name: "Run",      done: true,  streak: 5,  colorHex: "#E0A32E"),
            HabitLine(id: UUID(), emoji: "🧘", name: "Meditate", done: false, streak: 0,  colorHex: "#2FA39A"),
            HabitLine(id: UUID(), emoji: "💧", name: "Hydrate",  done: false, streak: 3,  colorHex: "#4FA96A"),
        ]
    )
}

/// Builds the widget timeline by reading the shared store file directly. Nothing
/// here is sandboxed, so no app group is needed — the widget, app, and CLI all
/// read the same `store.json` in Application Support.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UnbrokenEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (UnbrokenEntry) -> Void) {
        // In the gallery/preview, show the sample; otherwise read real data.
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(Self.entry(at: Date(), snapshot: HabitStore.snapshot(at: nil)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnbrokenEntry>) -> Void) {
        let now = Date()
        let snapshot = HabitStore.snapshot(at: nil)
        let dates = Self.refreshDates(from: now, settings: snapshot?.settings ?? DaySettings())
        let entries = dates.map { Self.entry(at: $0, snapshot: snapshot) }
        // Reload when the last scheduled entry is reached; the boundary dates
        // baked into `dates` guarantee we re-render exactly at the at-risk edge
        // and the day rollover even if the OS is stingy with background wakeups.
        let policy: TimelineReloadPolicy = .after(dates.last ?? now.addingTimeInterval(1800))
        completion(Timeline(entries: entries, policy: policy))
    }

    // MARK: - Timeline construction

    /// The dates we want the widget to re-render at: every 30 minutes for the
    /// next stretch, plus the exact at-risk boundary and the 3 AM day rollover.
    static func refreshDates(from now: Date, settings: DaySettings) -> [Date] {
        let calendar = Calendar.current
        var dates: Set<Date> = [now]

        // 30-minute cadence for the next 12 hours.
        for step in 1...24 {
            dates.insert(now.addingTimeInterval(Double(step) * 1800))
        }

        // Boundary moments for today and tomorrow's logical days.
        let today = settings.logicalDay(containing: now, calendar: calendar)
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let end = settings.end(ofLogicalDay: day, calendar: calendar)           // rollover
            let riskStart = calendar.date(byAdding: .hour, value: -settings.atRiskWindowHours, to: end) ?? end
            for moment in [riskStart, end] where moment > now {
                dates.insert(moment)
            }
        }

        // Keep the timeline bounded and ordered.
        return dates.sorted().filter { $0 <= now.addingTimeInterval(24 * 3600) }
    }

    /// Resolve an entry for a given moment from a (possibly nil) store snapshot.
    static func entry(at date: Date, snapshot: HabitStore.Snapshot?) -> UnbrokenEntry {
        guard let snapshot else {
            // No store yet (first run / unreadable file): a quiet empty ring.
            return UnbrokenEntry(date: date, state: .noHabits, completed: 0, total: 0, lines: [])
        }

        let settings = snapshot.settings
        let state = IconStateResolver.state(
            habits: snapshot.habits, entries: snapshot.entries, asOf: date, settings: settings
        )
        let day = settings.logicalDay(containing: date)
        let calendar = Calendar.current
        let dayKey = calendar.startOfDay(for: day)

        let completedIDs = Set(
            snapshot.entries
                .filter { calendar.startOfDay(for: $0.day) == dayKey }
                .map(\.habitID)
        )

        let ordered = snapshot.habits.sorted { $0.sortOrder < $1.sortOrder }
        let lines = ordered.map { habit -> HabitLine in
            let stats = StreakCalculator.stats(
                for: habit, entries: snapshot.entries, asOf: date, settings: settings
            )
            return HabitLine(
                id: habit.id,
                emoji: habit.emoji,
                name: habit.name,
                done: completedIDs.contains(habit.id),
                streak: stats.current,
                colorHex: habit.colorHex
            )
        }

        let completed = lines.filter(\.done).count
        return UnbrokenEntry(
            date: date, state: state, completed: completed, total: lines.count, lines: lines
        )
    }
}
