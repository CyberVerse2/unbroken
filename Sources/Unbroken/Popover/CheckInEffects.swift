import Foundation
import UnbrokenCore

/// The side effects that fire when the popover turns a habit *on* for today:
/// an optional spark sound, and a reschedule of the daily nudge so it stops
/// nagging once the day is complete. Reads app prefs straight from
/// `UserDefaults` so any screen can call it without threading bindings around.
///
/// Everything it calls (`Chime`, `Reminders`) no-ops outside a real app bundle,
/// so the preview harness stays inert.
@MainActor
enum CheckInEffects {
    /// Call right after a successful check-in that flipped a habit to done.
    static func didCheckIn(store: HabitStore, now: Date) {
        let defaults = UserDefaults.standard
        Chime.playCheckIn(enabled: defaults.bool(forKey: AppPrefs.sound))
        Reminders.shared.syncAfterCheckIn(
            enabled: defaults.bool(forKey: AppPrefs.reminders),
            hour: reminderHour(defaults),
            allDoneToday: allDoneToday(store: store, now: now)
        )
        // First check-in ever retires the dashboard coach-mark.
        if !defaults.bool(forKey: AppPrefs.didCheckInOnce) {
            defaults.set(true, forKey: AppPrefs.didCheckInOnce)
        }
    }

    /// Whether every habit is checked in for the logical day containing `now`.
    /// Empty store counts as *not* all-done (nothing to celebrate, nothing due).
    static func allDoneToday(store: HabitStore, now: Date) -> Bool {
        let today = store.settings.logicalDay(containing: now)
        let habits = store.habits
        return !habits.isEmpty && habits.allSatisfy { store.isCompleted($0, onLogicalDay: today) }
    }

    /// The reminder hour to reschedule at — the user's saved hour, or the
    /// default when they've never set one.
    static func reminderHour(_ defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: AppPrefs.reminderHour) as? Int ?? AppPrefs.defaultReminderHour
    }
}
