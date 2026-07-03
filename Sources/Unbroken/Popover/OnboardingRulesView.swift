import SwiftUI
import UnbrokenCore

/// Onboarding step: the one screen that teaches the app. Where to find it (the
/// menu bar), the streak rule stated plainly, the two mercies that keep it kind
/// (the 3 AM day and yesterday back-fill), and a one-line trust promise.
struct OnboardingRulesView: View {
    var scrolls: Bool = true
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("🔥").font(.system(size: 34)).floaty()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                Text("It lives in your menu bar")
                    .font(Theme.display(23, .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("Click the flame up top anytime to check in — no window to keep open.")
                    .font(Theme.text(13.5))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 26)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .padding(.bottom, 20)

            MaybeScroll(scrolls: scrolls) {
                VStack(spacing: 12) {
                    ruleCard(
                        icon: "flame.fill",
                        title: "How the streak works",
                        body: "Check in every day and your streak grows. Miss a day and it resets to zero."
                    )
                    ruleCard(
                        icon: "moon.stars.fill",
                        title: "Two mercies",
                        body: "The day doesn't end until 3 AM — so a late night still counts. And you can always back-fill yesterday if you forgot."
                    )
                    trustCard
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
            }

            PrimaryButton(title: "Got it — let's go 🔥", action: onFinish)
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
    }

    private func ruleCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.accent.opacity(0.10))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.display(14.5, .bold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(Theme.text(12.5))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
    }

    private var trustCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkFainter)
            Text("Everything stays on your Mac. No account, no cloud, no tracking.")
                .font(Theme.text(12))
                .foregroundStyle(Theme.inkFainter)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.emptyCell.opacity(0.5))
        )
    }
}
