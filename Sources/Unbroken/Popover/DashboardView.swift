import SwiftUI
import UnbrokenCore

/// The main screen: date + greeting, an animated day-progress bar, one card per
/// habit (emoji, name, streak, mini grid, check toggle), and a dashed add
/// button. All wired live to the store.
struct DashboardView: View {
    @Bindable var store: HabitStore
    let clock: AppClock
    let firstWeekday: Int
    var scrolls: Bool = true
    let onOpenSettings: () -> Void
    let onOpenDetail: (Habit) -> Void
    let onAdd: () -> Void
    let onDelete: (Habit) -> Void

    @AppStorage(AppPrefs.didCheckInOnce) private var didCheckInOnce = false

    private let calendar = Calendar.current

    private var today: Date { store.settings.logicalDay(containing: clock.now, calendar: calendar) }
    private var sortedHabits: [Habit] { store.habits.sorted { $0.sortOrder < $1.sortOrder } }
    private var doneCount: Int { sortedHabits.filter { store.isCompleted($0, onLogicalDay: today) }.count }
    private var total: Int { sortedHabits.count }

    /// The first-run coach-mark shows until the very first check-in, and only
    /// when there's actually something to tap.
    private var showCoachMark: Bool { !didCheckInOnce && doneCount < total && total > 0 }

    /// Row the coach-mark points at: the first habit still owed for today.
    private var firstUndoneIndex: Int {
        sortedHabits.firstIndex { !store.isCompleted($0, onLogicalDay: today) } ?? 0
    }

    private var greeting: String {
        if total > 0 && doneCount == total { return "You're unbroken today" }
        if doneCount == 0 { return "Let's get going" }
        return "Keep it rolling"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)

            progress
                .padding(.horizontal, 20)
                .padding(.top, 16)

            MaybeScroll(scrolls: scrolls) {
                VStack(spacing: 11) {
                    FocusCard(store: store, today: today, now: clock.now, interactive: scrolls)

                    if !sortedHabits.isEmpty {
                        SectionLabel("Habits")
                            .padding(.top, 4)
                    }

                    ForEach(Array(sortedHabits.enumerated()), id: \.element.id) { index, habit in
                        HabitRowCard(
                            store: store,
                            habit: habit,
                            today: today,
                            now: clock.now,
                            showCoachMark: showCoachMark && index == firstUndoneIndex,
                            onTap: { onOpenDetail(habit) },
                            onDelete: { onDelete(habit) }
                        )
                    }
                    addButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FlameDates.headerDate(clock.now))
                    .font(Theme.text(11, .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Theme.inkFaint)
                Text(greeting)
                    .font(Theme.display(23, .heavy))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            PillIconButton(systemName: "gearshape.fill", action: onOpenSettings, accessibilityLabel: "Settings")
        }
    }

    // MARK: Progress

    private var progress: some View {
        let pct = total > 0 ? Double(doneCount) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.emptyCell)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accent, Theme.accentWarm],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(9, geo.size.width * pct))
                }
            }
            .frame(height: 9)
            .animation(.snappy(duration: 0.35), value: pct)

            Text(total > 0 && doneCount == total
                 ? "All \(total) done — nice fire 🔥"
                 : "\(doneCount) of \(total) habits done today")
                .font(Theme.text(12, .medium))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: Add

    private var addButton: some View {
        Button(action: onAdd) {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add a habit")
                    .font(Theme.text(13.5, .medium))
            }
            .foregroundStyle(Theme.inkFainter)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Theme.dashedBorder)
            )
        }
        .buttonStyle(.plain)
    }
}

/// One habit card on the dashboard.
private struct HabitRowCard: View {
    @Bindable var store: HabitStore
    let habit: Habit
    let today: Date
    let now: Date
    var showCoachMark: Bool = false
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var popTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let calendar = Calendar.current

    private var isDone: Bool { store.isCompleted(habit, onLogicalDay: today) }
    private var stats: StreakStats { store.stats(for: habit, asOf: now) }

    private var last14: [Bool] {
        (0..<14).map { i in
            let day = calendar.date(byAdding: .day, value: -(13 - i), to: today) ?? today
            return store.isCompleted(habit, onLogicalDay: day)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left context opens detail.
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(habit.emoji.isEmpty ? "🔥" : habit.emoji)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(habit.color.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(habit.name)
                            .font(Theme.display(15.5, .bold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            HStack(spacing: 3) {
                                Text("🔥").font(.system(size: 11))
                                Text("\(stats.current)")
                                    .font(Theme.display(12, .bold))
                                    .foregroundStyle(habit.color)
                                    .flamePop(on: popTrigger)
                            }
                            MiniGrid(color: habit.color, done: last14)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            FlameCheckButton(color: habit.color, isOn: isDone, popTrigger: popTrigger) {
                toggle()
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1))
        )
        .contextMenu {
            Button("Open", action: onTap)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .overlay(alignment: .topTrailing) {
            if showCoachMark {
                CoachMark()
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
    }

    private func toggle() {
        if isDone {
            store.undoCheckIn(habit, asOf: now)
        } else {
            store.checkIn(habit, asOf: now)
            popTrigger.toggle()
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                CheckInEffects.didCheckIn(store: store, now: now)
            }
        }
    }
}

/// The first-run nudge: a warm accent bubble that floats above the first habit's
/// check ring and points down at it, retiring itself after the first check-in.
private struct CoachMark: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("Tap to log today 🔥")
                .font(Theme.text(12, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.accent)
                )
            DownTail()
                .fill(Theme.accent)
                .frame(width: 14, height: 7)
                .padding(.trailing, 22)
        }
        .shadow(color: Theme.accent.opacity(0.28), radius: 8, x: 0, y: 3)
        .floaty()
        // Lift the bubble above the row so its tail points down at the ring.
        .offset(x: -2, y: -42)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A little downward triangle — the coach-mark's tail.
private struct DownTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A small uppercase section divider label ("HABITS").
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(Theme.text(10.5, .semibold))
                .kerning(0.8)
                .foregroundStyle(Theme.inkFaint)
            Spacer()
        }
    }
}

// MARK: - Today's 3 (daily focus)

/// One editable slot in the "Today's 3" card. Local to the view — the store
/// holds the durable `FocusItem`s; these carry a stable id so the text fields
/// keep their identity while the user types.
private struct FocusSlot: Identifiable, Equatable {
    let id: UUID
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String, done: Bool) {
        self.id = id
        self.text = text
        self.done = done
    }

    var trimmed: String { text.trimmingCharacters(in: .whitespaces) }
    var isBlank: Bool { trimmed.isEmpty }

    static var emptyThree: [FocusSlot] { (0..<3).map { _ in FocusSlot(text: "", done: false) } }
}

/// "Today's 3" — the day's three most important things. A tiny daily to-do that
/// resets every logical day and never touches habits or streaks. The three text
/// fields are seeded from the store on appear and on day-rollover; every edit
/// and check writes straight back through `store.setFocus`.
private struct FocusCard: View {
    @Bindable var store: HabitStore
    let today: Date
    let now: Date
    /// The live app uses real `TextField`s; the preview harness passes
    /// `interactive: false` because `ImageRenderer` can't rasterize a TextField
    /// (it comes out as a blank box) — that path renders static text instead.
    var interactive: Bool = true

    @State private var slots: [FocusSlot] = FocusSlot.emptyThree

    private var filled: Int { slots.filter { !$0.isBlank }.count }
    private var done: Int { slots.filter { $0.done && !$0.isBlank }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            VStack(spacing: 6) {
                ForEach($slots) { $slot in
                    FocusRow(
                        slot: $slot,
                        placeholder: placeholder(for: $slot.wrappedValue),
                        interactive: interactive,
                        onToggle: { toggle($slot.wrappedValue.id) },
                        onEdit: commit
                    )
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1))
        )
        .onAppear(perform: seed)
        .onChange(of: today) { _, _ in seed() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Today's 3")
                .font(Theme.display(14.5, .bold))
                .foregroundStyle(Theme.ink)
            Text("most important things")
                .font(Theme.text(11.5, .medium))
                .foregroundStyle(Theme.inkFaint)
            Spacer()
            if filled > 0 {
                Text(done == filled ? "all done 🔥" : "\(done)/\(filled)")
                    .font(Theme.text(11.5, .semibold))
                    .foregroundStyle(done == filled ? Theme.accent : Theme.inkFaint)
            }
        }
    }

    private func placeholder(for slot: FocusSlot) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slot.id }) else { return "Something important" }
        switch index {
        case 0: return "The one thing that matters most"
        case 1: return "Second most important"
        default: return "Third most important"
        }
    }

    /// Reload the three slots from the store's record for today.
    private func seed() {
        let items = store.focusItems(asOf: now)
        slots = (0..<3).map { i in
            i < items.count
                ? FocusSlot(text: items[i].text, done: items[i].done)
                : FocusSlot(text: "", done: false)
        }
    }

    private func toggle(_ id: UUID) {
        guard let i = slots.firstIndex(where: { $0.id == id }), !slots[i].isBlank else { return }
        slots[i].done.toggle()
        commit()
    }

    /// Persist all three slots. The store trims blanks and drops an all-empty day.
    private func commit() {
        store.setFocus(slots.map { FocusItem(text: $0.text, done: $0.done) }, asOf: now)
    }
}

/// A single "Today's 3" row: a square checkbox plus the task text (an editable
/// field in the app, static text in previews). Checking is disabled until the
/// slot has text; a done task reads muted and struck through.
private struct FocusRow: View {
    @Binding var slot: FocusSlot
    let placeholder: String
    var interactive: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    private var checked: Bool { slot.done && !slot.isBlank }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(checked ? Theme.accent : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(checked ? Color.clear : Theme.dashedBorder, lineWidth: 1.6)
                        )
                        .frame(width: 22, height: 22)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(slot.isBlank)
            .accessibilityLabel(checked ? "Done" : "Not done")

            if interactive {
                TextField(placeholder, text: $slot.text)
                    .textFieldStyle(.plain)
                    .font(Theme.text(14, .medium))
                    .foregroundStyle(checked ? Theme.inkFaint : Theme.ink)
                    .strikethrough(checked, color: Theme.inkFaint)
                    .onSubmit(onEdit)
                    .onChange(of: slot.text) { _, _ in onEdit() }
            } else {
                Text(slot.isBlank ? placeholder : slot.text)
                    .font(Theme.text(14, .medium))
                    .foregroundStyle(slot.isBlank ? Theme.inkFaint : (checked ? Theme.inkFaint : Theme.ink))
                    .strikethrough(checked, color: Theme.inkFaint)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 2)
    }
}
