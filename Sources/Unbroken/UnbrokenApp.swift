import AppKit
import SwiftUI
import UnbrokenCore

@main
struct UnbrokenApp: App {
    /// One store for the whole app. `@State` keeps this single `@Observable`
    /// instance alive across the App's lifetime and drives view updates.
    @State private var store = HabitStore()
    /// Ticks so time-dependent state (day rollover, at-risk window) re-evaluates
    /// even when the store itself hasn't changed.
    @State private var clock = AppClock()

    init() {
        // Register Bricolage Grotesque + Hanken Grotesk before any view draws.
        FontLoader.register()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store, clock: clock)
        } label: {
            // The label IS the product. Reading `clock.now` here makes the icon
            // re-render on every tick; reading store state re-renders on every
            // mutation — together they keep the glyph honest about *right now*.
            let state = store.iconState(asOf: clock.now)
            MenuBarIcon.MenuBarIconView(state: state, progress: todayProgress)
                // Start the out-of-process file watcher exactly once, when the
                // (always-present) menu bar label first appears, and reconcile
                // the system-integration prefs (login item, reminders) with
                // their real OS state on launch.
                .task {
                    store.startWatchingForExternalChanges()
                    reconcileSystemPrefs()
                }
        }
        .menuBarExtraStyle(.window)

        // The main window: history grids, per-habit stats, and settings. It's an
        // LSUIElement app, so opening a window doesn't bring us forward on its
        // own — callers pair `openWindow` with `NSApp.activate` (see PopoverView).
        Window("Unbroken", id: "main") {
            MainWindowView(store: store, clock: clock)
        }
        .defaultSize(width: 760, height: 520)
        .windowResizability(.contentMinSize)
    }

    /// Fraction of today's habits already checked in — drives the partial arc so
    /// the icon's sweep matches reality instead of a placeholder half-fill.
    private var todayProgress: Double {
        let habits = store.habits
        guard !habits.isEmpty else { return 0 }
        let today = store.settings.logicalDay(containing: clock.now)
        let done = habits.reduce(into: 0) { count, habit in
            if store.isCompleted(habit, onLogicalDay: today) { count += 1 }
        }
        return Double(done) / Double(habits.count)
    }

    /// On launch, make the stored prefs agree with the real OS state and re-arm
    /// the reminder (the system can drop pending notifications). The settings
    /// toggles drive changes; this just heals drift.
    @MainActor
    private func reconcileSystemPrefs() {
        let defaults = UserDefaults.standard
        // Login item: SMAppService is the source of truth.
        defaults.set(LaunchAtLogin.isEnabled, forKey: AppPrefs.launchAtLogin)

        // Reminders: if the user has them on, make sure they're scheduled.
        if defaults.bool(forKey: AppPrefs.reminders) {
            let hour = defaults.object(forKey: AppPrefs.reminderHour) as? Int
                ?? AppPrefs.defaultReminderHour
            Reminders.shared.setEnabled(true, hour: hour, allDoneToday: allDoneToday)
        }
    }

    private var allDoneToday: Bool {
        let habits = store.habits
        guard !habits.isEmpty else { return false }
        let today = store.settings.logicalDay(containing: clock.now)
        return habits.allSatisfy { store.isCompleted($0, onLogicalDay: today) }
    }
}
