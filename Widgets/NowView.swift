import ChronoceptionKit
import SwiftUI
import WidgetKit

/// The widget in each of its sizes: the mark and a prompt when nothing is running,
/// otherwise what is running and its timer.
struct NowView: View {
    let running: WatchSnapshot.Running?

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        switch family {
        #if os(iOS)
        case .systemSmall:
            HomeScreenSquare(running: running)
                .containerBackground(Theme.canvas, for: .widget)
        #endif
        #if os(watchOS)
        case .accessoryCorner:
            corner
                .containerBackground(.fill.tertiary, for: .widget)
        #endif
        case .accessoryRectangular:
            rectangular
                .containerBackground(.fill.tertiary, for: .widget)
        case .accessoryInline:
            inline
                .containerBackground(.fill.tertiary, for: .widget)
        default:
            circular
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let running {
                VStack(spacing: 1) {
                    HourglassMark()
                        .frame(height: 12)
                    timer(running)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 3)
            } else {
                HourglassMark()
                    .padding(10)
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let running {
                Text(running.title)
                    .font(.headline)
                    .lineLimit(1)
                timer(running)
                    .font(.title2.monospacedDigit())
                    // Clay in full color (most watch faces); on the Lock Screen, which
                    // keeps only brightness, clay would come out dim.
                    .foregroundStyle(renderingMode == .fullColor ? Color.clay : .primary)
                    .widgetAccentable()
            } else {
                HStack(spacing: 5) {
                    HourglassMark()
                        .frame(height: 14)
                    Text("Chronoception")
                        .font(.headline)
                }
                Text(Self.prompt)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One line, above the clock: the timer first, so the title is what gets cut short.
    @ViewBuilder
    private var inline: some View {
        if let running {
            Text("\(timer(running)) \(running.title)")
        } else {
            Label(Self.prompt, systemImage: "hourglass")
        }
    }

    #if os(watchOS)
    private var corner: some View {
        HourglassMark()
            .padding(5)
            .widgetLabel {
                if let running {
                    timer(running)
                } else {
                    Text("说一件事")
                }
            }
    }
    #endif

    private static let prompt = "现在要做什么？"

    private func timer(_ running: WatchSnapshot.Running) -> Text {
        Text(timerInterval: running.start...Date.distantFuture, countsDown: false)
    }
}

#if os(iOS)
/// The home screen's square, in the app's colors.
private struct HomeScreenSquare: View {
    let running: WatchSnapshot.Running?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                HourglassMark(bottom: Theme.ink)
                    .frame(height: 22)
                Spacer()
                if let running {
                    Text("\(TimeText.clock(running.start)) 开始")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            Spacer(minLength: 4)
            if let running {
                Text(running.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(timerInterval: running.start...Date.distantFuture, countsDown: false)
                    .font(.system(.title, design: .serif).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .widgetAccentable()
            } else {
                Text("现在要做什么？")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("点一下，写下要做的事")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
