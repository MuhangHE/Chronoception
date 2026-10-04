import ChronoceptionKit
import SwiftUI
import WidgetKit

// Built twice from the same files: into the iPhone app (home screen and Lock Screen)
// and into the watch app (complications and the Smart Stack).

@main
struct ChronoceptionWidgets: WidgetBundle {
    var body: some Widget {
        NowWidget()
    }
}

/// What is running and for how long. A tap starts something: the phone opens its start
/// bar, and the watch goes straight to dictation.
struct NowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Now", provider: GlanceProvider()) { entry in
            NowView(running: entry.running)
                .widgetURL(AppLink.start)
        }
        .configurationDisplayName("Chronoception")
        #if os(watchOS)
        .description("正在计时的事和时长。没在计时的时候，点一下直接说。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
        #else
        .description("正在计时的事和时长。点一下，直接写下一件事。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        #endif
    }
}

nonisolated struct GlanceEntry: TimelineEntry {
    let date: Date
    let running: WatchSnapshot.Running?
}

/// Reads what the app saved last. The app reloads the widgets whenever that changes,
/// and a running timer counts by itself, so one entry is all it takes.
nonisolated struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: .now, running: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        completion(GlanceEntry(date: .now, running: Glance.running()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        completion(Timeline(entries: [GlanceEntry(date: .now, running: Glance.running())], policy: .never))
    }
}
