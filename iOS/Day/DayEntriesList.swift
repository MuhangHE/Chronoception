import ChronoceptionKit
import SwiftData
import SwiftUI

/// The entries and gaps of one day, oldest first.
struct DayEntriesList: View {
    let day: DateInterval
    let now: Date
    /// Today pins the running entry above the list, so the list leaves it out.
    let isToday: Bool
    @Binding var sheet: EntrySheet?
    let onDelete: (TimeEntry) -> Void

    @Query private var entries: [TimeEntry]

    init(
        day: DateInterval,
        now: Date,
        isToday: Bool,
        sheet: Binding<EntrySheet?>,
        onDelete: @escaping (TimeEntry) -> Void
    ) {
        self.day = day
        self.now = now
        self.isToday = isToday
        self._sheet = sheet
        self.onDelete = onDelete
        let lower = day.start
        let upper = day.end
        let openEnd = Date.distantFuture
        _entries = Query(
            filter: #Predicate<TimeEntry> { $0.start < upper && ($0.end ?? openEnd) > lower },
            sort: \.start
        )
    }

    var body: some View {
        let timeline = DayTimeline(day: day, entries: entries, now: now)
        List {
            Section {
                ForEach(visibleRows(of: timeline)) { row in
                    switch row {
                    case .entry(let entry):
                        entryRow(entry)
                    case .gap(let gap):
                        Button { sheet = EntrySheet(.new(gap)) } label: {
                            GapRow(gap: gap, day: day)
                        }
                        .accessibilityHint("补录这段时间")
                    }
                }
                .paperRows()
            } header: {
                if timeline.window != nil {
                    Text("已记录 \(DurationFormat.string(timeline.recorded)) · 未记录 \(DurationFormat.string(timeline.unrecorded))")
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryInk)
                }
            } footer: {
                if entries.isEmpty {
                    Text(isToday ? "在下面写一件事，点开始计时；也可以点空档补录。" : "点空档补录这一天。")
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        .paperBackground()
    }

    private func visibleRows(of timeline: DayTimeline) -> [DayTimeline.Row] {
        guard isToday else { return timeline.rows }
        return timeline.rows.filter { row in
            if case .entry(let entry) = row { return !entry.isRunning }
            return true
        }
    }

    private func entryRow(_ entry: TimeEntry) -> some View {
        Button { sheet = EntrySheet(.edit(entry)) } label: {
            EntryRow(entry: entry, day: day, now: now)
        }
        .swipeActions(edge: .trailing) {
            Button("删除", systemImage: "trash", role: .destructive) { onDelete(entry) }
                .tint(Theme.danger)
        }
        .swipeActions(edge: .leading) {
            Button("拆分", systemImage: "scissors") { sheet = EntrySheet(.split(entry)) }
                .tint(Theme.secondaryInk)
        }
        .contextMenu {
            Button("编辑", systemImage: "pencil") { sheet = EntrySheet(.edit(entry)) }
            Button("拆分", systemImage: "scissors") { sheet = EntrySheet(.split(entry)) }
            Button("删除", systemImage: "trash", role: .destructive) { onDelete(entry) }
        }
    }
}
