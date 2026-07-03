import SwiftUI
import WidgetKit

/// The Unbroken day widget — small and medium families, both driven by the same
/// timeline. Small is the ring writ large; medium adds the habit list.
struct UnbrokenWidget: Widget {
    let kind = "app.unbroken.Unbroken.widget.day"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            UnbrokenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Your day ring and habit streaks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Routes each widget family to its view.
struct UnbrokenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UnbrokenEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

/// The widget-extension entry point. A `WidgetBundle` marked `@main` provides
/// the executable's `main`, so this target ships as a real WidgetKit `.appex`
/// once packaged — see `make widget`.
@main
struct UnbrokenWidgetBundle: WidgetBundle {
    var body: some Widget {
        UnbrokenWidget()
    }
}
