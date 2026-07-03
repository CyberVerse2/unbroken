import AppKit
import Foundation
import Observation

/// A ticking clock the UI observes so time-dependent state re-evaluates even
/// when nothing in the store changed.
///
/// The menu bar icon depends on the wall clock in two ways the store can't
/// signal on its own: the logical day rolls over, and the "at-risk" window
/// opens as the day-end nears. Without an external tick SwiftUI would happily
/// show yesterday's icon forever. This publishes `now` on a ~60s cadence, plus
/// immediately on the events most likely to have moved us across a boundary
/// (day change, system clock change, wake from sleep).
@MainActor
@Observable
final class AppClock {
    /// The current moment. Read this (not `Date.now`) anywhere a view's output
    /// depends on the passage of time, so the view re-renders when it advances.
    private(set) var now: Date = .now

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        // ~60s cadence. `tolerance` lets the OS coalesce the wakeups — we don't
        // need second-precision, only "sometime this minute".
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Fire immediately on the events most likely to cross a day/at-risk
        // boundary, so the icon never lags a rollover the user can see happen.
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } })
        observers.append(center.addObserver(
            forName: NSNotification.Name("NSSystemClockDidChangeNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } })

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } })
    }

    // No deinit: exactly one `AppClock` is created at launch and lives for the
    // whole process, so the timer and observers are reclaimed at exit. (A
    // nonisolated deinit also can't touch these MainActor-isolated members.)

    private func tick() {
        now = .now
    }
}
