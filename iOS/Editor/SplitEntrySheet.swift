import ChronoceptionKit
import SwiftData
import SwiftUI

/// Cuts an entry in two, e.g. when one block of 上课 was really two lectures.
struct SplitEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: TimeEntry
    /// Times the entry can be cut at, leaving each part at least a minute long; nil if
    /// the entry is too short.
    private let range: ClosedRange<Date>?

    @State private var splitAt: Date
    @State private var errorMessage: String?

    init(entry: TimeEntry) {
        self.entry = entry
        let end = TimeLog.wholeMinute(entry.end ?? .now)
        let earliest = entry.start.addingTimeInterval(60)
        let latest = end.addingTimeInterval(-60)
        range = earliest <= latest ? earliest...latest : nil
        let middle = TimeLog.wholeMinute(entry.start.addingTimeInterval(end.timeIntervalSince(entry.start) / 2))
        _splitAt = State(initialValue: min(max(middle, earliest), max(earliest, latest)))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let range {
                    Section {
                        DatePicker("拆分时间", selection: $splitAt, in: range, displayedComponents: components(for: range))
                    } footer: {
                        Text("两段沿用原来的类别和备注，拆完可以分别修改。")
                    }
                    .paperRows()
                    Section("拆分后") {
                        part(from: entry.start, to: TimeLog.wholeMinute(splitAt))
                        part(from: TimeLog.wholeMinute(splitAt), to: entry.end)
                    }
                    .paperRows()
                } else {
                    Text("这条记录太短，不能再拆分。")
                        .foregroundStyle(Theme.secondaryInk)
                        .paperRows()
                }
            }
            .paperBackground()
            .navigationTitle("拆分记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .tint(Theme.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("拆分", action: split)
                        .disabled(range == nil)
                }
            }
            .errorAlert($errorMessage)
        }
        .presentationDetents([.medium, .large])
    }

    private func components(for range: ClosedRange<Date>) -> DatePickerComponents {
        Calendar.current.isDate(range.lowerBound, inSameDayAs: range.upperBound)
            ? .hourAndMinute
            : [.date, .hourAndMinute]
    }

    private func part(from start: Date, to end: Date?) -> some View {
        let duration = DurationFormat.string((end ?? .now).timeIntervalSince(start))
        return LabeledContent(TimeText.range(start, end), value: end == nil ? "已进行 \(duration)" : duration)
    }

    private func split() {
        do {
            try TimeLog(context: modelContext).split(entry, at: splitAt)
            dismiss()
        } catch {
            errorMessage = error.userMessage
        }
    }
}
