import ChronoceptionKit
import SwiftUI

// Rows sit inside Buttons, which tint hierarchical styles such as `.primary`; the
// theme's fixed colors keep them in ink.

struct EntryRow: View {
    let entry: TimeEntry
    let day: DateInterval
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(TimeText.title(of: entry))
                    .font(.headline)
                    .foregroundStyle(entry.title.isEmpty ? Theme.secondaryInk : Theme.ink)
                    .lineLimit(2)
                Spacer()
                Text(DurationFormat.string(entry.elapsed(at: now)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.secondaryInk)
            }
            Text(TimeText.range(entry.start, entry.end, within: day))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.vertical, 2)
    }
}

/// A stretch with no entry; tapping it opens the editor for that stretch.
struct GapRow: View {
    let gap: DateInterval
    let day: DateInterval

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .foregroundStyle(Theme.accent)
            Text("空档 \(TimeText.range(gap.start, gap.end, within: day))")
                .foregroundStyle(Theme.secondaryInk)
            Spacer()
            Text(DurationFormat.string(gap.duration))
                .foregroundStyle(Theme.secondaryInk)
        }
        .font(.subheadline.monospacedDigit())
    }
}
