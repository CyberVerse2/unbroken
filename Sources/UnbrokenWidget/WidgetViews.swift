import SwiftUI
import WidgetKit
import UnbrokenCore

// MARK: - Small

/// The streak flame, writ large on a cream tile — the whole product distilled to
/// one glance: is today's fire lit? The flame fills as habits get done; the
/// number underneath is the day's tally.
struct SmallWidgetView: View {
    let entry: UnbrokenEntry

    var body: some View {
        VStack(spacing: 7) {
            WidgetFlame(state: entry.state, progress: entry.progress)
                .frame(width: 60, height: 60)
            centerLabel
            dateText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Brand.card, for: .widget)
    }

    @ViewBuilder private var centerLabel: some View {
        switch entry.state {
        case .noHabits:
            Text("No habits")
                .font(Brand.text(13, .medium))
                .foregroundStyle(Brand.inkSoft)
        case .allDone:
            Text("All done")
                .font(Brand.display(18, .bold))
                .foregroundStyle(Brand.accent)
        default:
            Text("\(entry.completed)/\(entry.total)")
                .font(Brand.display(26, .bold))
                .foregroundStyle(entry.state == .atRisk ? Brand.orange : Brand.ink)
        }
    }

    private var dateText: some View {
        Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
            .font(Brand.text(11, .medium))
            .foregroundStyle(Brand.inkFaint)
    }
}

// MARK: - Medium

/// The flame on the left, up to five per-habit lines on the right — each with a
/// habit-coloured state dot, its emoji + name, and a 🔥 streak count in the
/// habit's own hue.
struct MediumWidgetView: View {
    let entry: UnbrokenEntry

    private var visibleLines: [HabitLine] { Array(entry.lines.prefix(5)) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                ZStack {
                    WidgetFlame(state: entry.state, progress: entry.progress)
                        .frame(width: 84, height: 84)
                    if entry.state != .allDone && entry.state != .noHabits && entry.total > 0 {
                        Text("\(entry.completed)/\(entry.total)")
                            .font(Brand.display(17, .bold))
                            .foregroundStyle(entry.state == .atRisk ? Brand.orange : Brand.ink)
                            .offset(y: 4)
                    }
                }
                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(Brand.text(10, .medium))
                    .foregroundStyle(Brand.inkFaint)
            }

            if entry.lines.isEmpty {
                emptyList
            } else {
                habitList
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Brand.card, for: .widget)
    }

    private var habitList: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(visibleLines) { line in
                let color = Color(hex: line.colorHex)
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(line.done ? AnyShapeStyle(color) : AnyShapeStyle(Brand.raised))
                        Circle()
                            .strokeBorder(line.done ? color : Brand.emptyCell, lineWidth: 1.4)
                        if line.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 15, height: 15)

                    Text(line.emoji)
                        .font(.system(size: 13))
                    Text(line.name)
                        .font(Brand.text(13, .semibold))
                        .foregroundStyle(Brand.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if line.streak > 0 {
                        HStack(spacing: 2) {
                            Text("🔥").font(.system(size: 11))
                            Text("\(line.streak)")
                                .font(Brand.display(12, .bold))
                                .foregroundStyle(color)
                        }
                    }
                }
            }
            if entry.lines.count > visibleLines.count {
                Text("+\(entry.lines.count - visibleLines.count) more")
                    .font(Brand.text(10, .medium))
                    .foregroundStyle(Brand.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No habits yet")
                .font(Brand.display(15, .bold))
                .foregroundStyle(Brand.ink)
            Text("Add one in Unbroken to start a streak.")
                .font(Brand.text(11, .medium))
                .foregroundStyle(Brand.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
