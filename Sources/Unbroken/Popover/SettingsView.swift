import AppKit
import SwiftUI
import UnbrokenCore

/// App preferences — each toggle drives a real system effect: reminders schedule
/// local notifications, sounds gate the check-in chime, week-start reshapes the
/// grids, and open-at-login registers the login item. Plus a streaks summary, a
/// way back to the main window, the version footer, and the always-present Quit
/// (this is an LSUIElement app).
struct SettingsView: View {
    @Bindable var store: HabitStore
    let clock: AppClock
    var scrolls: Bool = true
    let onBack: () -> Void
    let onOpenWindow: () -> Void

    @AppStorage(AppPrefs.reminders) private var dailyReminders = false
    @AppStorage(AppPrefs.sound) private var streakSounds = true
    @AppStorage(AppPrefs.weekStartMonday) private var weekStartsMonday = false
    @AppStorage(AppPrefs.launchAtLogin) private var launchAtLoginPref = false

    /// Mirrors the real login-item state; seeded from the system on appear so the
    /// toggle reflects reality, not just what we last stored.
    @State private var openAtLogin = LaunchAtLogin.isEnabled

    private var allDoneToday: Bool { CheckInEffects.allDoneToday(store: store, now: clock.now) }

    private var activeStreaks: Int {
        store.habits.filter { store.stats(for: $0, asOf: clock.now).current > 0 }.count
    }
    private var totalDays: Int { store.entries.count }
    private var bestRun: Int {
        store.habits.map { store.stats(for: $0, asOf: clock.now).best }.max() ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            MaybeScroll(scrolls: scrolls) {
                VStack(alignment: .leading, spacing: 20) {
                    remindersCard
                    streaksCard
                    windowRow
                    cliHint
                    quitRow
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
        }
        .onAppear { openAtLogin = LaunchAtLogin.isEnabled }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            PillIconButton(systemName: "chevron.left", action: onBack, accessibilityLabel: "Back")
            Text("Settings")
                .font(Theme.display(19, .bold))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }

    // MARK: Reminders

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("PREFERENCES")
            VStack(spacing: 0) {
                toggleRow("bell.fill", "Daily reminders",
                          "One nudge before the day ends, if a habit's still due", remindersBinding)
                divider
                toggleRow("speaker.wave.2.fill", "Streak sounds",
                          "Play a little spark when you check in", $streakSounds)
                divider
                toggleRow("calendar", "Week starts Monday",
                          "Otherwise weeks start on Sunday", $weekStartsMonday)
                divider
                toggleRow("power", "Open at login",
                          "Keep Unbroken in your menu bar every day", openAtLoginBinding)
            }
            .padding(.vertical, 4)
            .background(cardBackground)
        }
    }

    // MARK: Toggle wiring — each binding runs the real side effect on change.

    /// Turning reminders on asks the OS for permission first; if denied, the
    /// toggle falls back off. Either way we (re)schedule the daily nudge.
    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { dailyReminders },
            set: { want in
                let hour = CheckInEffects.reminderHour()
                let allDone = allDoneToday
                if want {
                    Task { @MainActor in
                        let granted = await Reminders.shared.requestAuthorization()
                        dailyReminders = granted
                        Reminders.shared.setEnabled(granted, hour: hour, allDoneToday: allDone)
                    }
                } else {
                    dailyReminders = false
                    Reminders.shared.setEnabled(false, hour: hour, allDoneToday: allDone)
                }
            }
        )
    }

    /// Registers / unregisters the real login item and mirrors it into prefs.
    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { openAtLogin },
            set: { want in
                LaunchAtLogin.set(want)
                openAtLogin = want
                launchAtLoginPref = want
            }
        )
    }

    private func toggleRow(_ icon: String, _ title: String, _ desc: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.10)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.text(13.5, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(desc)
                    .font(Theme.text(11.5))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            FlameToggle(isOn: binding)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Streaks summary

    private var streaksCard: some View {
        HStack(spacing: 13) {
            Text("🔥").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(activeStreaks) active \(activeStreaks == 1 ? "streak" : "streaks")")
                    .font(Theme.display(17, .bold))
                    .foregroundStyle(Theme.ink)
                Text("\(totalDays) total days logged · best run \(bestRun) days")
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: Window + Quit

    private var windowRow: some View {
        Button(action: onOpenWindow) {
            HStack(spacing: 12) {
                Image(systemName: "macwindow")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.emptyCell))
                Text("Open main window")
                    .font(Theme.text(13.5, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var quitRow: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#C0503A"))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#C0503A").opacity(0.10)))
                Text("Quit Unbroken")
                    .font(Theme.text(13.5, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("⌘Q")
                    .font(Theme.text(11.5, .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
    }

    // MARK: CLI hint

    private var cliHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.emptyCell))
            VStack(alignment: .leading, spacing: 2) {
                Text("Prefer the terminal?")
                    .font(Theme.text(13.5, .semibold))
                    .foregroundStyle(Theme.ink)
                (
                    Text("Run ")
                        .foregroundStyle(Theme.inkSoft)
                    + Text("unbroken done <habit>")
                        .font(Theme.text(11.5, .semibold).monospaced())
                        .foregroundStyle(Theme.accent)
                )
                .font(Theme.text(11.5))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Your streaks live on this Mac — no account, no cloud.")
                .font(Theme.text(11))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
            Text("Unbroken")
                .font(Theme.display(15, .heavy))
                .foregroundStyle(Theme.accent)
            Text("Version \(appVersion) · made to keep you going")
                .font(Theme.text(11))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    // MARK: Bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.text(10.5, .semibold))
            .kerning(0.8)
            .foregroundStyle(Theme.inkMuted)
            .padding(.leading, 4)
            .padding(.bottom, 4)
    }

    private var divider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1).padding(.leading, 60)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// A pill toggle: accent track on, warm track off, sliding white knob. Respects
/// Reduce Motion by dropping the slide animation.
struct FlameToggle: View {
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(isOn ? Theme.accent : Theme.dashedBorder)
                .frame(width: 44, height: 26)
                .overlay(
                    Circle()
                        .fill(.white)
                        .padding(3)
                        .frame(width: 26, height: 26)
                        .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                )
                .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}
