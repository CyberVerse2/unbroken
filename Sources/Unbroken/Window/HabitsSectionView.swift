import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UnbrokenCore

/// The heart of the main window: every habit as a card, in a vertical stack you
/// can drag to reorder. Add from the header, rename/delete from a card's context
/// menu (delete confirms). Empty state borrows the popover's waiting-ring nudge.
struct HabitsSectionView: View {
    let store: HabitStore
    let clock: AppClock
    /// Drag reordering is disabled in the PNG preview harness: `.onDrag`'s
    /// snapshot machinery corrupts ImageRenderer output. It's always on in the
    /// live app.
    var reorderEnabled: Bool = true

    @State private var dragging: Habit?
    @State private var isAdding = false
    @State private var habitToRename: Habit?
    @State private var habitToDelete: Habit?

    private let calendar = Calendar.current

    private var sortedHabits: [Habit] {
        store.habits.sorted { $0.sortOrder < $1.sortOrder }
    }
    private var today: Date {
        store.settings.logicalDay(containing: clock.now, calendar: calendar)
    }
    private var completedToday: Int {
        sortedHabits.filter { store.isCompleted($0, onLogicalDay: today) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !store.habits.isEmpty { progressBar }

            if store.habits.isEmpty {
                emptyState
            } else {
                ForEach(sortedHabits) { habit in
                    HabitCardView(
                        store: store,
                        habit: habit,
                        clock: clock,
                        onToggle: { toggle(habit) },
                        onRename: { habitToRename = habit },
                        onDelete: { habitToDelete = habit }
                    )
                    .opacity(dragging?.id == habit.id ? 0.4 : 1)
                    .modifier(ReorderDragModifier(
                        habit: habit, store: store, dragging: $dragging, enabled: reorderEnabled
                    ))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isAdding) {
            // Same flame form the popover uses, so creating a habit looks
            // identical everywhere. Next colour in the warm palette by default.
            flameForm(
                HabitFormView(
                    mode: .create,
                    initialColorHex: HabitPalette.colors[store.habits.count % HabitPalette.colors.count],
                    onBack: { isAdding = false },
                    onSubmit: { name, emoji, colorHex, frequency in
                        store.addHabit(name: name, emoji: emoji, colorHex: colorHex, frequency: frequency)
                        isAdding = false
                    }
                )
            )
        }
        .sheet(item: $habitToRename) { habit in
            // Rename is now a full edit (name, icon, colour, cadence) via the
            // same flame form. Delete routes through the confirm dialog.
            flameForm(
                HabitFormView(
                    mode: .edit,
                    initialName: habit.name,
                    initialEmoji: habit.emoji,
                    initialColorHex: habit.colorHex,
                    initialFrequency: habit.frequency,
                    onBack: { habitToRename = nil },
                    onSubmit: { name, emoji, colorHex, frequency in
                        store.update(habit, name: name, emoji: emoji, colorHex: colorHex, frequency: frequency)
                        habitToRename = nil
                    },
                    onDelete: {
                        habitToRename = nil
                        habitToDelete = habit
                    }
                )
            )
        }
        .confirmationDialog(
            "Delete “\(habitToDelete?.name ?? "")”?",
            isPresented: deleteDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let habit = habitToDelete { store.delete(habit) }
                habitToDelete = nil
            }
            Button("Cancel", role: .cancel) { habitToDelete = nil }
        } message: {
            Text("This erases its streak history. This can't be undone.")
        }
    }

    /// Wraps the popover's flame form in a fixed-size cream card for a window
    /// sheet, so create/edit looks identical to the popover.
    private func flameForm(_ form: HabitFormView) -> some View {
        form
            .frame(width: 392, height: 560)
            .background(Theme.card)
    }

    // MARK: Header

    private var greeting: String {
        if store.habits.isEmpty { return "Let's get going" }
        return completedToday == store.habits.count ? "You're unbroken today" : "Keep it rolling"
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(Theme.text(11, .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
                Text(greeting)
                    .font(Theme.display(23, .bold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button(action: { isAdding = true }) {
                Label("Add habit", systemImage: "plus")
                    .font(Theme.text(12.5, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Theme.accentWarm, Theme.accent],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Day progress

    private var progressBar: some View {
        let total = store.habits.count
        let fraction = total > 0 ? Double(completedToday) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.emptyCell)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accentWarm, Theme.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 9)
            Text(completedToday == total
                 ? "All \(total) done — nice fire 🔥"
                 : "\(completedToday) of \(total) habits done today")
                .font(Theme.text(12, .medium))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            WindowFlame(done: 0, total: 0, size: 54)
            VStack(spacing: 6) {
                Text("Nothing to keep yet.")
                    .font(Theme.display(18, .bold))
                    .foregroundStyle(Theme.ink)
                Text("Add one small thing you want to do every day.\nTomorrow you'll want to keep the streak.")
                    .font(Theme.text(13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            Button(action: { isAdding = true }) {
                Label("Light your first spark", systemImage: "flame.fill")
                    .font(Theme.text(13, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Theme.accentWarm, Theme.accent],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    // MARK: Actions

    private func toggle(_ habit: Habit) {
        if store.isCompleted(habit, onLogicalDay: today) {
            store.undoCheckIn(habit, asOf: clock.now)
        } else {
            store.checkIn(habit, asOf: clock.now)
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { habitToDelete != nil },
            set: { if !$0 { habitToDelete = nil } }
        )
    }
}

/// Wraps a card in the drag-source + drop-target for reordering, when enabled.
private struct ReorderDragModifier: ViewModifier {
    let habit: Habit
    let store: HabitStore
    @Binding var dragging: Habit?
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    dragging = habit
                    return NSItemProvider(object: habit.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: HabitReorderDropDelegate(item: habit, store: store, dragging: $dragging)
                )
        } else {
            content
        }
    }
}

/// Live drag-to-reorder: as the dragged card passes over another, we commit the
/// move through the store so `sortOrder` (and persistence) stays authoritative.
private struct HabitReorderDropDelegate: DropDelegate {
    let item: Habit
    let store: HabitStore
    @Binding var dragging: Habit?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.id != item.id else { return }
        let ordered = store.habits.sorted { $0.sortOrder < $1.sortOrder }
        guard let from = ordered.firstIndex(where: { $0.id == dragging.id }),
              let to = ordered.firstIndex(where: { $0.id == item.id }) else { return }
        // `moveHabits` uses SwiftUI onMove semantics: destination is expressed
        // pre-removal, so dragging downward lands after the target.
        store.moveHabits(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
