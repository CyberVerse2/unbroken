import AppKit
import SwiftUI
import UnbrokenCore

// windowpreview — the window/widget agent's harness. Renders the warm-flame
// main window (habits + settings + empty first-run) to PNGs so the reskin can be
// reviewed without a GUI session. Output: dist/ui-preview/flamewindow-*.png.
// Top-level code in main.swift is @MainActor in Swift 6.

@MainActor func render(view: some View, name: String, scheme: ColorScheme) {
    let wrapped = view.environment(\.colorScheme, scheme)
    let renderer = ImageRenderer(content: wrapped)
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
    let url = dir.appendingPathComponent("\(name).png")
    try? png.write(to: url)
    print("wrote \(url.path)")
}

/// Seeds ~six months of history (via historical `asOf` moments so the
/// today-or-yesterday backfill window is satisfied per call) across four habits
/// with distinct warm-palette colours, so the contribution grids show real,
/// per-habit-coloured shape.
@MainActor func seedStore() -> HabitStore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("unbroken-windowpreview-\(UUID().uuidString)")
    let store = HabitStore(fileURL: dir.appendingPathComponent("store.json"))
    let cal = Calendar.current
    let now = Date()
    let today = store.settings.logicalDay(containing: now, calendar: cal)
    func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
    func noon(_ d: Date) -> Date { cal.date(byAdding: .hour, value: 12, to: d)! }
    func mark(_ habit: Habit, _ n: Int) { store.checkIn(habit, day: day(n), asOf: noon(day(n))) }

    let read = store.addHabit(name: "Read 20 Pages", emoji: "📖", colorHex: "#3E7BC4")
    let ship = store.addHabit(name: "Ship something", emoji: "🚀", colorHex: "#E2603A")
    let run = store.addHabit(name: "Morning Run", emoji: "🏃", colorHex: "#E0A32E")
    let meditate = store.addHabit(name: "Meditate", emoji: "🧘", colorHex: "#2FA39A")

    // Read: months of near-daily habit with a rock-solid recent run.
    for n in 0...22 { mark(read, n) }
    for n in 24...170 where n % 7 != 3 && n % 11 != 0 { mark(read, n) }

    // Ship: works in sprints, then rests — a broken current streak, big best.
    for n in 6...25 { mark(ship, n) }
    for n in 45...58 { mark(ship, n) }
    for n in 80...92 { mark(ship, n) }
    for n in 120...129 { mark(ship, n) }

    // Run: a short, fresh streak plus older scattered efforts.
    for n in 0...5 { mark(run, n) }
    for n in 30...36 { mark(run, n) }
    for n in [50, 51, 60, 61, 62, 90, 110, 111] { mark(run, n) }

    // Meditate: a couple of early attempts, nothing recent — no streak.
    for n in [95, 96, 97, 130, 131, 150] { mark(meditate, n) }

    return store
}

// Register the design fonts (Bricolage Grotesque + Hanken Grotesk) so previews
// render with the real type, not a system fallback.
FontLoader.register(from: URL(fileURLWithPath: "Support/Fonts"))

let clock = AppClock()

@MainActor func window(_ store: HabitStore, section: MainWindowSection, height: CGFloat) -> some View {
    // Anchor to the top: the un-scrolled content is taller than the frame, and a
    // plain `.frame(height:)` would centre it and clip the header off the top.
    MainWindowView(store: store, clock: clock, section: section, scrolls: false)
        .frame(width: 780, height: height, alignment: .top)
}

let populated = seedStore()
let empty = HabitStore(
    fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("unbroken-windowpreview-empty-\(UUID().uuidString)/store.json")
)

render(view: window(populated, section: .habits, height: 1180), name: "flamewindow-habits-light", scheme: .light)
render(view: window(populated, section: .habits, height: 1180), name: "flamewindow-habits-dark", scheme: .dark)
render(view: window(populated, section: .settings, height: 620), name: "flamewindow-settings-light", scheme: .light)
render(view: window(empty, section: .habits, height: 620), name: "flamewindow-empty-light", scheme: .light)

// Create-habit sheet (flame form) as shown in the window.
render(
    view: HabitFormView(
        mode: .create,
        scrolls: false,
        initialName: "Read 20 pages",
        initialEmoji: "📖",
        initialColorHex: "#3E7BC4",
        onBack: {}, onSubmit: { _, _, _, _ in }
    ).frame(width: 392, height: 560).background(Theme.card),
    name: "flamewindow-create",
    scheme: .light
)
