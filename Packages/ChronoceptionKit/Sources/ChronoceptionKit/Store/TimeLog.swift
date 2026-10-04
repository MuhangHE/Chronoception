import Foundation
import SwiftData

public enum TimeLogError: Error, Equatable {
    case invalidInterval
    case startsBeforeRunningEntry
    case splitPointOutsideEntry
    case emptyTitle
}

/// Every read and write of the time log goes through here, so its rules live in one
/// place: at most one entry runs at a time, and every finished entry lasts at least a
/// minute and is kept to the whole minute. Each change is saved immediately.
public struct TimeLog {
    /// The shortest finished entry. Ending sooner still keeps the entry, at this length.
    public static let minimumDuration: TimeInterval = 60

    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// `date` with the seconds dropped. Seconds only add noise to a time diary, and
    /// would make the shown 09:00–10:00 disagree with a stored 59 minutes 30 seconds.
    public static func wholeMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    }

    // MARK: - Running

    public func runningEntry() throws -> TimeEntry? {
        var descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.end == nil },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Starts an event titled with what the user typed, ending whatever was running.
    /// The text is also kept as a voice note, to be tidied in the background.
    @discardableResult
    public func startEvent(_ text: String, at time: Date = .now) throws -> TimeEntry {
        let title = Self.clean(text)
        guard !title.isEmpty else { throw TimeLogError.emptyTitle }
        let note = VoiceNote(recordedAt: time, transcript: title)
        context.insert(note)
        let entry = try insertRunning(title: title, at: time, source: .typed, voiceNote: note)
        try context.save()
        return entry
    }

    /// Starts a running entry, ending whatever was running at the same moment. It keeps
    /// its exact start, so its timer starts at zero, until it ends.
    @discardableResult
    public func start(title: String = "", at time: Date = .now, source: EntrySource = .manual) throws -> TimeEntry {
        let entry = try insertRunning(title: title, at: time, source: source, voiceNote: nil)
        try context.save()
        return entry
    }

    /// Ends the running entry, if any.
    public func stopRunning(at time: Date = .now) throws {
        try finishRunning(at: time)
        try context.save()
    }

    // MARK: - Finished entries

    /// Records a finished block of time. Overlaps with other entries are allowed;
    /// check `entries(overlapping:)` first to warn about them.
    @discardableResult
    public func addEntry(start: Date, end: Date, title: String, source: EntrySource = .manual) throws -> TimeEntry {
        let start = Self.wholeMinute(start)
        let end = Self.wholeMinute(end)
        guard end > start else { throw TimeLogError.invalidInterval }
        let entry = TimeEntry(start: start, end: end, note: Self.clean(title), source: source)
        context.insert(entry)
        try context.save()
        return entry
    }

    /// Edits an entry. `end` may stay nil only for an entry that is already running,
    /// which then keeps its exact start unless the minute changed.
    public func update(_ entry: TimeEntry, start: Date, end: Date?, title: String) throws {
        let start = Self.wholeMinute(start)
        let end = end.map(Self.wholeMinute)
        if let end {
            guard end > start else { throw TimeLogError.invalidInterval }
        } else {
            guard entry.isRunning else { throw TimeLogError.invalidInterval }
        }
        if end != nil || Self.wholeMinute(entry.start) != start {
            entry.start = start
        }
        entry.end = end
        entry.note = Self.clean(title)
        try context.save()
    }

    public func delete(_ entry: TimeEntry) throws {
        context.delete(entry)
        try context.save()
    }

    /// Cuts an entry in two at `time` and returns the second part. Splitting a running
    /// entry leaves the second part running.
    @discardableResult
    public func split(_ entry: TimeEntry, at time: Date, now: Date = .now) throws -> TimeEntry {
        let time = Self.wholeMinute(time)
        let originalEnd = entry.end
        guard time > entry.start, time < (originalEnd ?? now) else {
            throw TimeLogError.splitPointOutsideEntry
        }
        let second = TimeEntry(
            start: time,
            end: originalEnd,
            category: entry.category,
            note: entry.note,
            source: entry.source,
            voiceNote: entry.voiceNote
        )
        entry.start = Self.wholeMinute(entry.start)
        entry.end = time
        context.insert(second)
        try context.save()
        return second
    }

    // MARK: - Reading

    /// Entries touching the calendar day that contains `day`, oldest first.
    public func entries(on day: Date, calendar: Calendar = .current) throws -> [TimeEntry] {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        return try entries(overlapping: interval)
    }

    /// Entries that overlap `interval`, oldest first. A running entry counts as
    /// lasting indefinitely.
    public func entries(overlapping interval: DateInterval) throws -> [TimeEntry] {
        let lower = interval.start
        let upper = interval.end
        let openEnd = Date.distantFuture
        return try context.fetch(FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.start < upper && ($0.end ?? openEnd) > lower },
            sortBy: [SortDescriptor(\.start)]
        ))
    }

    /// Every entry, oldest first.
    public func allEntries() throws -> [TimeEntry] {
        try context.fetch(FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.start)]))
    }

    // MARK: - Older data

    /// Entries made by tapping a category, before categories were dropped, have no
    /// title of their own; this gives them the category's name. Returns how many changed.
    @discardableResult
    public func adoptCategoryNamesAsTitles() throws -> Int {
        let untitled = try context.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.note == "" }))
        var changed = 0
        for entry in untitled {
            guard let name = entry.category?.name, !name.isEmpty else { continue }
            entry.note = name
            changed += 1
        }
        if changed > 0 { try context.save() }
        return changed
    }

    // MARK: - Internals

    func insertRunning(title: String, at time: Date, source: EntrySource, voiceNote: VoiceNote?) throws -> TimeEntry {
        try finishRunning(at: time)
        let entry = TimeEntry(start: time, note: Self.clean(title), source: source, voiceNote: voiceNote)
        context.insert(entry)
        return entry
    }

    /// Ends whatever is running at `time`, keeping it however short, to the whole minute.
    func finishRunning(at time: Date) throws {
        let running = try context.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.end == nil }))
        for entry in running {
            guard time >= entry.start else { throw TimeLogError.startsBeforeRunningEntry }
            let start = Self.wholeMinute(entry.start)
            entry.start = start
            entry.end = max(Self.wholeMinute(time), start.addingTimeInterval(Self.minimumDuration))
        }
    }

    static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
