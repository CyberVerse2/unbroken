import SwiftUI
import UnbrokenCore

/// Onboarding step: offer the daily nudge, honestly. A streak app only works if
/// you actually check in before the day flips — so this is the one gentle
/// reminder that keeps the flame alive. Primary asks the OS for permission;
/// secondary lets them skip without guilt.
struct OnboardingRemindersView: View {
    /// Async so the primary button can await the real permission prompt.
    let onEnable: () async -> Void
    let onSkip: () -> Void

    @State private var working = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            Text("🔔")
                .font(.system(size: 56))
                .floaty()
                .padding(.bottom, 22)

            Text("One nudge a day")
                .font(Theme.display(26, .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 12)

            Text("Around 8 PM, we'll send one gentle reminder to check in before the day ends — but only if you still have a habit left to do. No pressure, no spam.")
                .font(Theme.text(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 34)
                .padding(.bottom, 28)

            PrimaryButton(title: working ? "Asking…" : "Turn on reminders") {
                guard !working else { return }
                working = true
                Task {
                    await onEnable()
                    working = false
                }
            }
            .padding(.horizontal, 24)
            .disabled(working)

            Button(action: onSkip) {
                Text("Maybe later")
                    .font(Theme.text(13, .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }
}
