import AppKit
import SwiftUI
import UnbrokenCore

/// The flame popover: a single 392pt surface that swaps between screens —
/// a four-step onboarding, then dashboard, create, detail, settings. First run
/// (never onboarded) walks the welcome → pick → reminders → rules flow; existing
/// users are migrated straight to the dashboard. Everything is wired live to the
/// store, and check-ins fire real sound + reminder side effects.
struct PopoverView: View {
    @Bindable var store: HabitStore
    let clock: AppClock

    /// Which screen is showing. The `onboard*` cases form the first-run flow.
    enum Screen: Equatable {
        case onboardWelcome
        case onboardPick
        case onboardForm
        case onboardReminders
        case onboardRules
        case dashboard
        case create
        case edit(UUID)
        case detail(UUID)
        case settings
    }

    @State private var screen: Screen
    @State private var habitToDelete: Habit?

    @AppStorage(AppPrefs.weekStartMonday) private var weekStartsMonday = false
    @AppStorage(AppPrefs.hasOnboarded) private var hasOnboarded = false
    @AppStorage(AppPrefs.reminders) private var remindersPref = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    init(store: HabitStore, clock: AppClock) {
        self.store = store
        self.clock = clock

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: AppPrefs.hasOnboarded) {
            _screen = State(initialValue: .dashboard)
        } else if !store.habits.isEmpty {
            // Existing user from before onboarding existed — never march them
            // through a first-run flow; migrate silently.
            defaults.set(true, forKey: AppPrefs.hasOnboarded)
            _screen = State(initialValue: .dashboard)
        } else {
            _screen = State(initialValue: .onboardWelcome)
        }
    }

    private var firstWeekday: Int { AppPrefs.firstWeekday(mondayStart: weekStartsMonday) }

    /// Whether every habit is done for today's logical day (for reminder sync).
    private var allDoneToday: Bool { CheckInEffects.allDoneToday(store: store, now: clock.now) }

    var body: some View {
        ZStack {
            content
                .transition(transition)
        }
        .frame(width: 392, height: 588)
        .background(Theme.card)
        .environment(\.colorScheme, .light)
        .confirmationDialog(
            "Delete “\(habitToDelete?.name ?? "")”?",
            isPresented: deleteBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let habit = habitToDelete { store.delete(habit) }
                habitToDelete = nil
                go(.dashboard)
            }
            Button("Cancel", role: .cancel) { habitToDelete = nil }
        } message: {
            Text("This erases its streak history. This can't be undone.")
        }
    }

    // MARK: Screens

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .onboardWelcome:
            OnboardingWelcomeView(onStart: { go(.onboardPick) })
                .id("welcome")

        case .onboardPick:
            OnboardingPickHabitView(
                onPick: { starter in
                    store.addHabit(name: starter.name, emoji: starter.emoji,
                                   colorHex: starter.colorHex, frequency: .daily)
                    go(.onboardReminders)
                },
                onMakeOwn: { go(.onboardForm) }
            )
            .id("onboardPick")

        case .onboardForm:
            HabitFormView(
                mode: .onboarding,
                onBack: { go(.onboardPick) },
                onSubmit: { name, emoji, color, freq in
                    store.addHabit(name: name, emoji: emoji, colorHex: color, frequency: freq)
                    go(.onboardReminders)
                }
            )
            .id("onboardForm")

        case .onboardReminders:
            OnboardingRemindersView(
                onEnable: {
                    let granted = await Reminders.shared.requestAuthorization()
                    if granted {
                        remindersPref = true
                        Reminders.shared.setEnabled(true, hour: AppPrefs.defaultReminderHour,
                                                    allDoneToday: allDoneToday)
                    }
                    go(.onboardRules)
                },
                onSkip: { go(.onboardRules) }
            )
            .id("onboardReminders")

        case .onboardRules:
            OnboardingRulesView(onFinish: {
                hasOnboarded = true
                go(.dashboard)
            })
            .id("onboardRules")

        case .dashboard:
            DashboardView(
                store: store,
                clock: clock,
                firstWeekday: firstWeekday,
                onOpenSettings: { go(.settings) },
                onOpenDetail: { go(.detail($0.id)) },
                onAdd: { go(.create) },
                onDelete: { habitToDelete = $0 }
            )
            .id("dashboard")

        case .create:
            HabitFormView(
                mode: .create,
                onBack: { go(.dashboard) },
                onSubmit: { name, emoji, color, freq in
                    store.addHabit(name: name, emoji: emoji, colorHex: color, frequency: freq)
                    go(.dashboard)
                }
            )
            .id("create")

        case .edit(let id):
            if let habit = habit(id) {
                HabitFormView(
                    mode: .edit,
                    initialName: habit.name,
                    initialEmoji: habit.emoji,
                    initialColorHex: habit.colorHex,
                    onBack: { go(.detail(id)) },
                    onSubmit: { name, emoji, color, freq in
                        store.update(habit, name: name, emoji: emoji, colorHex: color, frequency: freq)
                        go(.detail(id))
                    },
                    onDelete: { habitToDelete = habit }
                )
                .id("edit")
            } else {
                fallbackToDashboard
            }

        case .detail(let id):
            if let habit = habit(id) {
                DetailView(
                    store: store,
                    habit: habit,
                    clock: clock,
                    firstWeekday: firstWeekday,
                    onBack: { go(.dashboard) },
                    onOpenSettings: { go(.settings) },
                    onEdit: { go(.edit(id)) }
                )
                .id("detail")
            } else {
                fallbackToDashboard
            }

        case .settings:
            SettingsView(
                store: store,
                clock: clock,
                onBack: { go(.dashboard) },
                onOpenWindow: openMainWindow
            )
            .id("settings")
        }
    }

    /// A habit that vanished under us (deleted) bounces back to the dashboard.
    private var fallbackToDashboard: some View {
        Color.clear.onAppear { go(.dashboard) }
    }

    // MARK: Navigation

    private func go(_ destination: Screen) {
        if reduceMotion {
            screen = destination
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                screen = destination
            }
        }
    }

    private var transition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            )
    }

    private func habit(_ id: UUID) -> Habit? { store.habits.first { $0.id == id } }

    /// Opens the history/settings window and fronts the app — an LSUIElement app
    /// won't surface a window without an explicit activate.
    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { habitToDelete != nil }, set: { if !$0 { habitToDelete = nil } })
    }
}

/// The menu bar icon writ larger: a progress ring for today that fills as habits
/// are checked in and flips to a solid disc when everything's done.
///
/// Retained here because the main window's header (owned by the window agent)
/// draws it; the flame popover itself uses its own progress bar.
struct DayProgressRing: View {
    let done: Int
    let total: Int

    private var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }
    private var isComplete: Bool { total > 0 && done == total }

    var body: some View {
        ZStack {
            if isComplete {
                Circle().fill(.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.background)
            } else {
                Circle().stroke(.quaternary, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(done)/\(total)")
                    .font(.system(size: 8.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
        .animation(.snappy(duration: 0.3), value: progress)
        .accessibilityLabel("\(done) of \(total) habits done today")
    }
}
