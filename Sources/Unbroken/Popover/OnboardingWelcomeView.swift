import SwiftUI
import UnbrokenCore

/// First-run welcome (onboarding step 0): a floating flame, the promise, and a
/// single way forward. Existing users never see this — they're migrated straight
/// to the dashboard — so there's no confusing "I already have habits" escape here.
struct OnboardingWelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Text("🔥")
                .font(.system(size: 72))
                .floaty()
                .padding(.bottom, 26)

            headline
                .padding(.horizontal, 28)
                .padding(.bottom, 12)

            Text("Pick one small thing. Do it today. Then keep the flame going — one day at a time.")
                .font(Theme.text(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 34)
                .padding(.bottom, 30)

            PrimaryButton(title: "Start my first streak", action: onStart)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }

    private var headline: some View {
        // "Keep the streak" then "unbroken." in accent.
        (
            Text("Keep the streak\n")
                .foregroundStyle(Theme.ink)
            + Text("unbroken.")
                .foregroundStyle(Theme.accent)
        )
        .font(Theme.display(34, .heavy))
        .multilineTextAlignment(.center)
        .lineSpacing(2)
    }
}
