import ChronoceptionKit
import SwiftUI

/// The running event, pinned above the timeline with a live timer.
struct RunningEntryCard: View {
    let entry: TimeEntry
    let onEdit: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TimeText.title(of: entry))
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                        Text("\(TimeText.clock(entry.start)) 开始")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    Spacer(minLength: 8)
                    Text(timerInterval: entry.start...Date.distantFuture, countsDown: false)
                        .font(.system(.title2, design: .serif).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                        .fixedSize()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("编辑这件事")

            Button("结束", action: onStop)
                .buttonStyle(ClayButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.hairline)
        }
    }
}
