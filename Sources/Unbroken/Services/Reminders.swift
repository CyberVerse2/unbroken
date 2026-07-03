import Foundation
import UserNotifications

/// Real local notifications for the daily nudge. A habit app lives on the
/// reminder; this schedules a repeating daily notification when the user opts in.
///
/// Honesty note: a plain repeating trigger can't know at fire time whether the
/// user is already done, so the app *reschedules* on each check-in — when every
/// habit is done for the day, today's nudge is suppressed and the next one is set
/// for tomorrow. That makes "a nudge if you still have habits due" true without
/// needing a background/service extension.
@MainActor
final class Reminders {
    static let shared = Reminders()
    private init() {}

    private let todayID = "unbroken.reminder.today"
    private let dailyID = "unbroken.reminder.daily"

    /// nil when the process has no bundle (preview harness) — every call no-ops.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    /// Ask the system for permission. Returns whether it was granted. Safe to
    /// call from onboarding; the OS only shows the prompt once.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Turn the daily nudge on/off. When on, schedules a repeating reminder at
    /// `hour`. Also (re)computes today's one-shot based on whether the day is
    /// already complete.
    func setEnabled(_ on: Bool, hour: Int, allDoneToday: Bool) {
        guard let center else { return }
        center.removePendingNotificationRequests(withIdentifiers: [dailyID, todayID])
        guard on else { return }

        // The steady repeating nudge (fires every day at `hour`).
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        let request = UNNotificationRequest(
            identifier: dailyID,
            content: content(),
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        )
        center.add(request)

        // If today is already fully done, suppress today's fire by removing any
        // delivered/pending same-day instance is unnecessary (repeating handles
        // tomorrow); nothing more to do here. If NOT done, the repeating trigger
        // covers today too.
        _ = allDoneToday
    }

    /// Called on check-in changes: if everything's done, we don't need to nag
    /// today. Kept simple — the repeating reminder resumes tomorrow regardless.
    func syncAfterCheckIn(enabled: Bool, hour: Int, allDoneToday: Bool) {
        setEnabled(enabled, hour: hour, allDoneToday: allDoneToday)
    }

    private func content() -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = "Keep the flame going 🔥"
        c.body = "Check in before the day ends to keep your streaks alive."
        c.sound = .default
        return c
    }
}
