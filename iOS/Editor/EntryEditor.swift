import ChronoceptionKit
import SwiftData
import SwiftUI

/// Adds a finished entry, or edits an existing one (including ending a running one
/// at an earlier time, for when you forgot to stop it).
struct EntryEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil when adding. The body never reads its properties: after a delete it may run
    /// once more, and a deleted model must not be touched.
    private let entry: TimeEntry?
    private let entryID: UUID?
    private let wasRunning: Bool

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var stillRunning: Bool
    /// Entries overlapping the edited times, refreshed when the times change. Kept as
    /// text so the body never fetches or holds models.
    @State private var overlaps: [Overlap] = []
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    private struct Overlap: Identifiable {
        let id: UUID
        let title: String
        let range: String
    }

    init(newIn interval: DateInterval) {
        entry = nil
        entryID = nil
        wasRunning = false
        _title = State(initialValue: "")
        _start = State(initialValue: interval.start)
        _end = State(initialValue: interval.end)
        _stillRunning = State(initialValue: false)
    }

    init(editing entry: TimeEntry) {
        self.entry = entry
        entryID = entry.id
        wasRunning = entry.isRunning
        _title = State(initialValue: entry.title)
        _start = State(initialValue: entry.start)
        _end = State(initialValue: entry.end ?? .now)
        _stillRunning = State(initialValue: entry.isRunning)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("做了什么", text: $title, axis: .vertical)
                }
                .paperRows()

                Section {
                    DatePicker("开始", selection: $start, in: ...Date.now)
                    if wasRunning {
                        Toggle("进行中", isOn: $stillRunning)
                    }
                    if !stillRunning {
                        DatePicker("结束", selection: $end, in: ...Date.now)
                    }
                    LabeledContent("时长", value: durationText)
                } footer: {
                    if !isValid {
                        Text("结束时间要晚于开始时间。")
                            .foregroundStyle(Theme.danger)
                    }
                }
                .paperRows()

                if !overlaps.isEmpty {
                    Section {
                        ForEach(overlaps) { other in
                            LabeledContent(other.title, value: other.range)
                        }
                    } header: {
                        Text("和这些记录重叠")
                    } footer: {
                        Text("仍然可以保存，只是这段时间会同时出现在两条记录里。")
                    }
                    .paperRows()
                }

                if entry != nil {
                    Section {
                        Button("删除记录", role: .destructive) { confirmingDelete = true }
                            .foregroundStyle(Theme.danger)
                    }
                    .paperRows()
                }
            }
            .paperBackground()
            .navigationTitle(entry == nil ? "补录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .tint(Theme.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("删除这条记录？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive, action: delete)
            }
            .errorAlert($errorMessage)
            .task(id: [startMinute, endMinute ?? .distantFuture]) { refreshOverlaps() }
        }
    }

    private var startMinute: Date { TimeLog.wholeMinute(start) }

    /// nil while the entry keeps running.
    private var endMinute: Date? { stillRunning ? nil : TimeLog.wholeMinute(end) }

    private var isValid: Bool {
        guard let endMinute else { return true }
        return endMinute > startMinute
    }

    private var durationText: String {
        let upper = endMinute ?? .now
        guard upper > startMinute else { return "—" }
        return DurationFormat.string(upper.timeIntervalSince(startMinute))
    }

    private func refreshOverlaps() {
        let upper = endMinute ?? .now
        guard upper > startMinute else {
            overlaps = []
            return
        }
        let interval = DateInterval(start: startMinute, end: upper)
        let found = (try? TimeLog(context: modelContext).entries(overlapping: interval)) ?? []
        overlaps = found
            .filter { $0.id != entryID }
            .map { Overlap(id: $0.id, title: TimeText.title(of: $0), range: TimeText.range($0.start, $0.end)) }
    }

    private func save() {
        let log = TimeLog(context: modelContext)
        do {
            if let entry {
                try log.update(entry, start: start, end: stillRunning ? nil : end, title: title)
            } else {
                try log.addEntry(start: start, end: end, title: title)
            }
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func delete() {
        guard let entry else { return }
        do {
            try TimeLog(context: modelContext).delete(entry)
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }
    }
}
