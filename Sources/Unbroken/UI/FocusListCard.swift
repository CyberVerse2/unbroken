import SwiftUI
import UnbrokenCore

/// "Today's 3" — the day's three most important things, rendered identically in
/// the popover and the main window. It's a daily to-do that resets each logical
/// day, and clearing the list (finishing every task you wrote) feeds a *focus
/// streak*: the list is a habit in its own right, as central as any other.
///
/// The three fields are seeded from the store on appear and on day-rollover;
/// every edit and check writes straight back through `store.setFocus`.
struct FocusListCard: View {
    @Bindable var store: HabitStore
    let today: Date
    let now: Date
    /// The live app uses real `TextField`s; the preview harness passes
    /// `interactive: false` because `ImageRenderer` can't rasterize a TextField
    /// (it comes out blank) — that path renders static text instead.
    var interactive: Bool = true

    @State private var slots: [FocusSlot] = FocusSlot.emptyThree

    private var filled: Int { slots.filter { !$0.isBlank }.count }
    private var done: Int { slots.filter { $0.done && !$0.isBlank }.count }
    private var cleared: Bool { filled > 0 && done == filled }
    private var streak: Int { store.focusStats(asOf: now).current }

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
        .padding(14)
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
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("Today's 3")
                    .font(Theme.display(15, .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if streak > 0 {
                    HStack(spacing: 3) {
                        Text("🔥").font(.system(size: 11.5))
                        Text("\(streak)")
                            .font(Theme.display(13, .bold))
                            .foregroundStyle(cleared ? Theme.accent : Theme.inkSoft)
                    }
                    .accessibilityLabel("\(streak) day focus streak")
                }
            }
            Text(statusLine)
                .font(Theme.text(11.5, .medium))
                .foregroundStyle(cleared ? Theme.accent : Theme.inkFaint)
        }
    }

    private var statusLine: String {
        if filled == 0 { return "your three most important things today" }
        if cleared {
            return streak > 1 ? "cleared — \(streak) days in a row 🔥" : "cleared for today 🔥"
        }
        return "\(done) of \(filled) done today"
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

/// One editable slot. Local to the view — the store holds the durable
/// `FocusItem`s; these carry a stable id so the text fields keep their identity
/// while the user types.
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

/// A small uppercase section divider label ("HABITS").
struct SectionLabel: View {
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
