import AppKit
import SwiftUI
import UnbrokenCore

/// The two rooms of the main window.
enum MainWindowSection: String, CaseIterable, Identifiable {
    case habits
    case settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .habits: return "Habits"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .habits: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}

/// The main window: a quiet sidebar for switching rooms, and a content area that
/// holds the habit cards or the settings. Built from plain stacks (not a
/// NavigationSplitView / List) so it renders faithfully to PNG in the preview
/// harness and stays in exact step with the popover's design language.
struct MainWindowView: View {
    let store: HabitStore
    let clock: AppClock
    /// The real app scrolls its content; the PNG preview harness can't render a
    /// ScrollView, so it renders the raw content at a tall fixed frame instead.
    let scrolls: Bool
    @State private var section: MainWindowSection

    init(store: HabitStore, clock: AppClock, section: MainWindowSection = .habits, scrolls: Bool = true) {
        self.store = store
        self.clock = clock
        self.scrolls = scrolls
        _section = State(initialValue: section)
    }

    private let calendar = Calendar.current

    private var today: Date {
        store.settings.logicalDay(containing: clock.now, calendar: calendar)
    }
    private var completedToday: Int {
        store.habits.filter { store.isCompleted($0, onLogicalDay: today) }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                selection: $section,
                done: completedToday,
                total: store.habits.count
            )
            .frame(width: 194)

            scrollableContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(WindowStyle.ground)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if scrolls {
            ScrollView { content.frame(maxWidth: .infinity, alignment: .topLeading) }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .habits:
            // `scrolls` is false only in the PNG preview harness, where the
            // drag-source snapshot corrupts ImageRenderer — so gate reorder on it.
            HabitsSectionView(store: store, clock: clock, reorderEnabled: scrolls)
        case .settings:
            SettingsSectionView(store: store)
        }
    }
}

/// The left rail: the Unbroken wordmark over a small ambient progress ring, then
/// the room selector. Selection reads as a soft rounded fill — the same rounded
/// hover language as the rows, never a hairline.
private struct SidebarView: View {
    @Binding var selection: MainWindowSection
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 22)

            VStack(spacing: 4) {
                ForEach(MainWindowSection.allCases) { item in
                    SidebarRow(
                        item: item,
                        isSelected: selection == item,
                        action: { selection = item }
                    )
                }
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WindowStyle.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.divider).frame(width: 1)
        }
    }

    private var brand: some View {
        HStack(spacing: 11) {
            WindowFlame(done: done, total: total, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Unbroken")
                    .font(Theme.display(16, .bold))
                    .foregroundStyle(Theme.ink)
                Text(total == 0 ? "no habits yet"
                     : (done == total ? "all done today 🔥" : "\(done)/\(total) today"))
                    .font(Theme.text(11, .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

private struct SidebarRow: View {
    let item: MainWindowSection
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20)
                Text(item.title)
                    .font(Theme.text(13.5, isSelected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.inkSoft)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var fill: Color {
        if isSelected { return Theme.accent.opacity(0.12) }
        if hovering { return Theme.ink.opacity(0.05) }
        return .clear
    }
}
