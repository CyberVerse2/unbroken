import AppKit
import SwiftUI
import UnbrokenCore

/// Minimal settings: when the day ends, how wide the at-risk window is, and a
/// plain-words explanation of why 3 AM is the sane default — plus where the
/// data lives. Grouped by soft cards and spacing, no hairline dividers.
struct SettingsSectionView: View {
    @Bindable var store: HabitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Settings")
                .font(Theme.display(23, .bold))
                .foregroundStyle(Theme.ink)

            streaksCard

            VStack(alignment: .leading, spacing: 12) {
                dayCard
                Text(explanation)
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }

            dataCard

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Your streaks (live from the engine)

    private var activeStreaks: Int {
        store.habits.filter { store.stats(for: $0).current > 0 }.count
    }
    private var totalLogged: Int { store.entries.count }
    private var bestRun: Int {
        store.habits.map { store.stats(for: $0).best }.max() ?? 0
    }

    private var streaksCard: some View {
        HStack(spacing: 13) {
            WindowFlame(done: activeStreaks, total: max(store.habits.count, 1), size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(activeStreaks) active \(activeStreaks == 1 ? "streak" : "streaks")")
                    .font(Theme.display(16, .bold))
                    .foregroundStyle(Theme.ink)
                Text("\(totalLogged) total days logged · best run \(bestRun) days")
                    .font(Theme.text(12, .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: The day

    private var dayCard: some View {
        VStack(spacing: 0) {
            settingRow {
                rowLabel("Day ends at", "When one logical day rolls into the next")
            } control: {
                Picker("", selection: $store.settings.dayEndHour) {
                    ForEach(0...6, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 110)
            }

            settingRow {
                rowLabel("At-risk window", "How early the icon starts warning you")
            } control: {
                Stepper(value: $store.settings.atRiskWindowHours, in: 1...8) {
                    Text("\(store.settings.atRiskWindowHours) \(store.settings.atRiskWindowHours == 1 ? "hour" : "hours")")
                        .font(.system(size: 13))
                        .monospacedDigit()
                }
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(cardBackground)
    }

    private var explanation: String {
        "A check-in after midnight still counts for the day before. With the day ending at \(hourLabel(store.settings.dayEndHour)), a 12:30 AM note counts toward yesterday — so a late night doesn't break your streak."
    }

    // MARK: Data

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATA")
                .font(Theme.text(9.5, .semibold))
                .kerning(0.6)
                .foregroundStyle(Theme.inkFaint)
            Text("Stored locally as JSON. No accounts, no sync.")
                .font(Theme.text(12.5, .medium))
                .foregroundStyle(Theme.inkSoft)
            Text(HabitStore.defaultStoreURL.path)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.inkFaint)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    // MARK: Row building blocks

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.card)
            .shadow(color: Theme.ink.opacity(0.05), radius: 6, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }

    private func settingRow<L: View, C: View>(
        @ViewBuilder label: () -> L,
        @ViewBuilder control: () -> C
    ) -> some View {
        HStack(alignment: .center) {
            label()
            Spacer(minLength: 16)
            control()
        }
        .padding(.vertical, 12)
    }

    private func rowLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.text(13.5, .semibold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(Theme.text(11.5, .medium))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12
        let display = h == 0 ? 12 : h
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(display):00 \(suffix)"
    }
}
