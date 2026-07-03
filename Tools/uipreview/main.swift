import AppKit
import SwiftUI
import UnbrokenCore

// Renders each flame popover screen to dist/ui-preview/flame-<screen>.png so the
// warm UI can be reviewed without a GUI session. Every screen is drawn at 392pt
// wide, scale 2, light scheme — a cream card floating on the peach wallpaper,
// exactly as it reads behind the menu bar.

let popoverWidth: CGFloat = 392

@MainActor func renderFlame(_ screen: some View, name: String, height: CGFloat? = nil) {
    let sized = height.map { AnyView(screen.frame(width: popoverWidth, height: $0)) }
        ?? AnyView(screen.frame(width: popoverWidth))
    let card = sized
        .environment(\.colorScheme, .light)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)

    let composed = ZStack {
        Theme.wallpaper
        card.padding(24)
    }
    .frame(width: popoverWidth + 48)
    .environment(\.colorScheme, .light)

    let renderer = ImageRenderer(content: composed)
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("render failed: \(name)\n", stderr)
        return
    }
    let dir = URL(fileURLWithPath: "dist/ui-preview")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("flame-\(name).png")
    try? png.write(to: url)
    print("wrote \(url.path)")
}

/// Seeds ~6 months of real check-ins (via historical `asOf` moments so each
/// lands inside the today-or-yesterday backfill window) so grids and streaks
/// have honest shape.
@MainActor func seedStore() -> HabitStore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("unbroken-flamepreview-\(UUID().uuidString)")
    let store = HabitStore(fileURL: dir.appendingPathComponent("store.json"))
    let cal = Calendar.current
    let today = store.settings.logicalDay(containing: Date(), calendar: cal)
    func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
    func noon(_ d: Date) -> Date { cal.date(byAdding: .hour, value: 12, to: d)! }
    func mark(_ h: Habit, _ n: Int) { store.checkIn(h, day: day(n), asOf: noon(day(n))) }

    let read = store.addHabit(name: "Read 20 pages", emoji: "📖", colorHex: "#3E7BC4", frequency: .daily)
    let run = store.addHabit(name: "Morning run", emoji: "🏃", colorHex: "#E0A32E", frequency: .weekdays)
    let meditate = store.addHabit(name: "Meditate", emoji: "🧘", colorHex: "#2FA39A", frequency: .daily)
    let water = store.addHabit(name: "Drink water", emoji: "💧", colorHex: "#3E7BC4", frequency: .daily)

    for n in 0...24 { mark(read, n) }                       // current streak 25
    for n in 26...170 where n % 7 != 3 && n % 11 != 0 { mark(read, n) }
    for n in 0...5 { mark(run, n) }                         // fresh 6
    for n in 30...36 { mark(run, n) }
    for n in [50, 51, 60, 61, 62, 90, 110, 111] { mark(run, n) }
    for n in 0...11 { mark(meditate, n) }                   // 12
    for n in 20...40 { mark(meditate, n) }
    for n in [95, 96, 97, 130, 131, 150] { mark(water, n) } // broken, no current streak
    return store
}

/// A brand-new store — two habits, nothing checked in today — so the dashboard
/// coach-mark ("Tap to log today 🔥") has an undone first row to point at.
@MainActor func coachMarkStore() -> HabitStore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("unbroken-coachmark-\(UUID().uuidString)")
    let store = HabitStore(fileURL: dir.appendingPathComponent("store.json"))
    store.addHabit(name: "Read 20 pages", emoji: "📖", colorHex: "#3E7BC4", frequency: .daily)
    store.addHabit(name: "Meditate", emoji: "🧘", colorHex: "#2FA39A", frequency: .daily)
    return store
}

// Register the design fonts so previews render with the real type.
FontLoader.register(from: URL(fileURLWithPath: "Support/Fonts"))

// Fresh coach-mark state for this run's dashboard renders.
UserDefaults.standard.set(false, forKey: AppPrefs.didCheckInOnce)

let clock = AppClock()
let store = seedStore()
let detailHabit = store.habits.sorted { $0.sortOrder < $1.sortOrder }[0] // long streak

// 1. Onboarding welcome (Spacer-driven — needs a fixed popover height)
renderFlame(
    OnboardingWelcomeView(onStart: {}),
    name: "onboarding-welcome",
    height: 588
)

// 2. Onboarding — pick a starter habit
renderFlame(
    OnboardingPickHabitView(scrolls: false, onPick: { _ in }, onMakeOwn: {}),
    name: "onboarding-pick",
    height: 588
)

// 3. Onboarding — reminders step
renderFlame(
    OnboardingRemindersView(onEnable: {}, onSkip: {}),
    name: "onboarding-reminders",
    height: 588
)

// 4. Onboarding — orientation + rules
renderFlame(
    OnboardingRulesView(scrolls: false, onFinish: {}),
    name: "onboarding-rules",
    height: 588
)

// 5. First-habit / create form (prefilled to show live preview + selections)
renderFlame(
    HabitFormView(
        mode: .onboarding,
        scrolls: false,
        initialName: "Read 20 pages",
        initialEmoji: "📖",
        initialColorHex: "#3E7BC4",
        onBack: {},
        onSubmit: { _, _, _, _ in }
    ),
    name: "form"
)

// 6. Dashboard (coach-mark shown: a fresh store with one undone habit)
let coachStore = coachMarkStore()
renderFlame(
    DashboardView(
        store: coachStore, clock: clock, firstWeekday: 1, scrolls: false,
        onOpenSettings: {}, onOpenDetail: { _ in }, onAdd: {}, onDelete: { _ in }
    ),
    name: "dashboard-coachmark",
    height: 588
)

// 7. Dashboard (seeded, no coach-mark — didCheckInOnce set below)
UserDefaults.standard.set(true, forKey: AppPrefs.didCheckInOnce)
renderFlame(
    DashboardView(
        store: store, clock: clock, firstWeekday: 1, scrolls: false,
        onOpenSettings: {}, onOpenDetail: { _ in }, onAdd: {}, onDelete: { _ in }
    ),
    name: "dashboard"
)

// 8. Detail
renderFlame(
    DetailView(
        store: store, habit: detailHabit, clock: clock, firstWeekday: 1, scrolls: false,
        onBack: {}, onOpenSettings: {}, onEdit: {}
    ),
    name: "detail"
)

// 9. Settings
renderFlame(
    SettingsView(store: store, clock: clock, scrolls: false, onBack: {}, onOpenWindow: {}),
    name: "settings"
)
