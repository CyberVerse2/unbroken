import SwiftUI
import UnbrokenCore

/// The create / edit / first-habit form. Live preview tile up top, then name,
/// icon grid, and color swatches. Reused for onboarding ("Your first habit" →
/// "Light the first spark 🔥") and later adds/edits.
///
/// Cadence is intentionally absent: the streak engine is strict-daily, so every
/// habit is created `.daily`. A repeat picker would be a false promise until the
/// engine understands non-daily streaks.
struct HabitFormView: View {
    enum Mode { case onboarding, create, edit }

    let mode: Mode
    var scrolls: Bool = true
    let onBack: () -> Void
    let onSubmit: (_ name: String, _ emoji: String, _ colorHex: String, _ frequency: HabitFrequency) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @FocusState private var nameFocused: Bool

    private static let emojis = ["🌱", "🏃", "📖", "🧘", "💧", "🌙", "🥗", "✍️", "🎸", "🧹", "💪", "☕"]

    init(
        mode: Mode,
        scrolls: Bool = true,
        initialName: String = "",
        initialEmoji: String = "🌱",
        initialColorHex: String = HabitPalette.colors[0],
        // Accepted for source-compat with existing callers, but ignored: the
        // form no longer offers a cadence, and always submits `.daily`.
        initialFrequency: HabitFrequency = .daily,
        onBack: @escaping () -> Void,
        onSubmit: @escaping (String, String, String, HabitFrequency) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.scrolls = scrolls
        self.onBack = onBack
        self.onSubmit = onSubmit
        self.onDelete = onDelete
        _name = State(initialValue: initialName)
        _emoji = State(initialValue: initialEmoji)
        _colorHex = State(initialValue: initialColorHex)
    }

    private var color: Color { Color(hex: colorHex) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var title: String {
        switch mode {
        case .onboarding: return "Your first habit"
        case .create: return "New habit"
        case .edit: return "Edit habit"
        }
    }
    private var submitTitle: String {
        switch mode {
        case .onboarding: return "Light the first spark 🔥"
        case .create: return "Add habit"
        case .edit: return "Save changes"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            MaybeScroll(scrolls: scrolls) {
                VStack(alignment: .leading, spacing: 18) {
                    previewTile
                    nameField
                    iconPicker
                    colorPicker
                    if mode == .edit, let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete habit")
                                .font(Theme.text(13, .medium))
                                .foregroundStyle(Color(hex: "#C0503A"))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            PrimaryButton(title: submitTitle, fill: trimmedName.isEmpty ? Theme.accent.opacity(0.4) : Theme.accent) {
                guard !trimmedName.isEmpty else { return }
                onSubmit(trimmedName, emoji, colorHex, .daily)
            }
            .disabled(trimmedName.isEmpty)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear { nameFocused = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            PillIconButton(systemName: "chevron.left", action: onBack, accessibilityLabel: "Back")
            Text(title)
                .font(Theme.display(19, .bold))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }

    // MARK: Preview tile

    private var previewTile: some View {
        HStack(spacing: 13) {
            Text(emoji.isEmpty ? "🔥" : emoji)
                .font(.system(size: 24))
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))

            VStack(alignment: .leading, spacing: 3) {
                Text(trimmedName.isEmpty ? "Your habit" : trimmedName)
                    .font(Theme.display(16, .bold))
                    .foregroundStyle(trimmedName.isEmpty ? Theme.inkFaint : Theme.ink)
                    .lineLimit(1)
                Text("Daily · 0 day streak")
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.14))
        )
    }

    // MARK: Name

    @ViewBuilder
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel("NAME")
            Group {
                if scrolls {
                    TextField("Read 20 pages", text: $name)
                        .textFieldStyle(.plain)
                        .focused($nameFocused)
                } else {
                    // Preview harness: ImageRenderer draws live TextFields as a
                    // blank yellow box, so show the value as static text instead.
                    Text(trimmedName.isEmpty ? "Read 20 pages" : trimmedName)
                        .foregroundStyle(trimmedName.isEmpty ? Theme.inkFaint : Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
                .font(Theme.text(14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.fieldBorder, lineWidth: 1)
                        )
                )
        }
    }

    // MARK: Icon

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldLabel("ICON")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(Self.emojis, id: \.self) { option in
                    let selected = option == emoji
                    Button { emoji = option } label: {
                        Text(option)
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? Theme.accent.opacity(0.12) : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(selected ? Theme.accent : Theme.fieldBorder,
                                                          lineWidth: selected ? 1.6 : 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Color

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldLabel("COLOR")
            HStack(spacing: 12) {
                ForEach(HabitPalette.colors, id: \.self) { hex in
                    let selected = hex == colorHex
                    Button { colorHex = hex } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.ink, lineWidth: selected ? 2.5 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.vertical, 3)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.text(10.5, .semibold))
            .kerning(0.8)
            .foregroundStyle(Theme.inkMuted)
    }
}
