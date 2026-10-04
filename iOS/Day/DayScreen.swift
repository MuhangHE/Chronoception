import ChronoceptionKit
import SwiftData
import SwiftUI

/// The main screen: one day of the log. Today also pins the running event on top and
/// has the start bar at the bottom: write what you are doing, start, and later end.
struct DayScreen: View {
    let watchLink: WatchLink

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<TimeEntry> { $0.end == nil }, sort: \TimeEntry.start, order: .reverse)
    private var runningEntries: [TimeEntry]

    /// 0 is today, -1 yesterday, and so on.
    @State private var dayOffset = 0
    /// A moment of today, refreshed when the date changes so the screen rolls over at midnight.
    @State private var today = Date.now
    @State private var sheet: EntrySheet?
    @State private var errorMessage: String?
    @State private var tidier = TitleTidier()

    private var running: TimeEntry? { runningEntries.first }
    private var isToday: Bool { dayOffset == 0 }

    private var day: DateInterval {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
        return calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 24 * 60 * 60)
    }

    var body: some View {
        let day = day
        let title = TimeText.dayTitle(day.start, offset: dayOffset)
        NavigationStack {
            // Only the list ticks, once a minute, so gaps and totals keep up with the clock.
            TimelineView(.everyMinute) { timeline in
                DayEntriesList(day: day, now: timeline.date, isToday: isToday, sheet: $sheet, onDelete: delete)
            }
            .safeAreaBar(edge: .top) {
                if isToday, let running {
                    RunningEntryCard(
                        entry: running,
                        onEdit: { sheet = EntrySheet(.edit(running)) },
                        onStop: stop
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Theme.canvas)
                }
            }
            .safeAreaBar(edge: .bottom) {
                if isToday {
                    StartBar(isRunning: running != nil, onStart: startEvent)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { dayNavigation(title: title) }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet.kind {
            case .new(let interval): EntryEditor(newIn: interval)
            case .edit(let entry): EntryEditor(editing: entry)
            case .split(let entry): SplitEntrySheet(entry: entry)
            case .settings: SettingsView()
            }
        }
        .errorAlert($errorMessage)
        .sensoryFeedback(.impact, trigger: running?.id)
        .task {
            tidier.start(with: modelContext)
            watchLink.onWatchEvent = { [tidier] noteID in
                Task { await tidier.tidy(noteID: noteID) }
            }
            watchLink.publish()
        }
        // Whatever changes what is running (here, on the watch, or a tidied title) reaches the watch.
        .onChange(of: running.map { WatchSnapshot.Running(id: $0.id, title: $0.title, start: $0.start) }) {
            watchLink.publish()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            today = .now
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            today = .now
            Task { await tidier.tidyWaiting() }
        }
    }

    @ToolbarContentBuilder
    private func dayNavigation(title: String) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 16) {
                Button("前一天", systemImage: "chevron.left") { dayOffset -= 1 }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Button("后一天", systemImage: "chevron.right") { dayOffset += 1 }
                    .disabled(isToday)
            }
            .labelStyle(.iconOnly)
            .tint(Theme.ink)
        }
        ToolbarItem(placement: .topBarLeading) {
            if isToday {
                Button("设置", systemImage: "gearshape") { sheet = EntrySheet(.settings) }
                    .tint(Theme.ink)
            } else {
                Button("回到今天") { dayOffset = 0 }
            }
        }
    }

    /// Starts right away; the title is tidied in the background.
    private func startEvent(_ text: String) {
        perform {
            let entry = try TimeLog(context: modelContext).startEvent(text)
            if let noteID = entry.voiceNote?.id {
                Task { await tidier.tidy(noteID: noteID) }
            }
        }
    }

    private func stop() {
        perform { try TimeLog(context: modelContext).stopRunning() }
    }

    private func delete(_ entry: TimeEntry) {
        perform { try TimeLog(context: modelContext).delete(entry) }
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            errorMessage = error.userMessage
        }
    }
}

#if DEBUG
#Preview {
    let container = try! ChronoceptionStore.makeContainer(inMemory: true)
    DemoData.fill(TimeLog(context: container.mainContext))
    return DayScreen(watchLink: WatchLink(container: container)).modelContainer(container)
}
#endif
