import Foundation

/// `@AppStorage` keys for app-level preferences (not habit data — that lives in
/// the store). Centralized so the settings UI and the services that act on them
/// agree on the same keys.
enum AppPrefs {
    static let reminders = "pref.reminders"           // Bool — daily nudge on
    static let reminderHour = "pref.reminderHour"     // Int  — hour (0–23), default 20
    static let sound = "pref.sound"                   // Bool — chime on check-in
    static let weekStartMonday = "pref.weekStartMonday" // Bool — week grids start Mon
    static let launchAtLogin = "pref.launchAtLogin"   // Bool — mirror of SMAppService
    static let hasOnboarded = "pref.hasOnboarded"     // Bool — first-run gate
    static let didCheckInOnce = "pref.didCheckInOnce" // Bool — coach-mark gate

    static let defaultReminderHour = 20

    /// First weekday for Calendar-style layouts: 2 (Mon) or 1 (Sun).
    static func firstWeekday(mondayStart: Bool) -> Int { mondayStart ? 2 : 1 }
}
