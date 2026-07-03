import AppKit
import SwiftUI

/// The single-click check-in control — the app's primary interaction, drawn in
/// the brand's ring language: off is a hollow ring with a small break in it
/// (a streak waiting to be secured); tapping closes the gap and fills the ring.
/// On is a solid disc with a checkmark, mirroring the menu bar's allDone state.
struct CheckInToggle: View {
    let isOn: Bool
    /// Diameter of the visible ring. The hit target is padded larger than this.
    var diameter: CGFloat = 26
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // The ring: broken when off, closed when on. The gap sits at
                // the top, where the menu bar's atRisk break lives.
                Circle()
                    .trim(from: isOn ? 0 : 0.07, to: isOn ? 1 : 0.93)
                    .stroke(
                        isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(ringColor),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(1)

                Circle()
                    .fill(.primary)
                    .padding(1)
                    .opacity(isOn ? 1 : 0)
                    .scaleEffect(isOn ? 1 : 0.5)

                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.42, weight: .bold))
                    .foregroundStyle(.background)
                    .opacity(isOn ? 1 : 0)
                    .scaleEffect(isOn ? 1 : 0.4)
            }
            .frame(width: diameter, height: diameter)
            // Pad the tappable area so a lazy click near the ring still lands.
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.snappy(duration: 0.25), value: isOn)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityLabel(isOn ? "Checked in" : "Not checked in")
        .accessibilityAddTraits(.isButton)
    }

    private var ringColor: Color {
        hovering ? .primary : .secondary.opacity(0.55)
    }
}
