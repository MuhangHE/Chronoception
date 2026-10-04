import Foundation
import SwiftData

extension TimeLog {
    public func entry(id: UUID) throws -> TimeEntry? {
        var descriptor = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// What the watch should show now.
    public func watchSnapshot(madeAt: Date = .now) throws -> WatchSnapshot {
        let running = try runningEntry().map { WatchSnapshot.Running(id: $0.id, title: $0.title, start: $0.start) }
        return WatchSnapshot(running: running, madeAt: madeAt)
    }

    /// Applies a command from the watch, which may arrive late (the phone was out of
    /// reach) or twice. Returns the voice note of an event it started, to be tidied.
    @discardableResult
    public func apply(_ command: WatchCommand) throws -> VoiceNote? {
        switch command {
        case .start(let id, let text, let time):
            return try startFromWatch(id: id, text: text, at: time)
        case .stop(let id, let time):
            try stopFromWatch(id: id, at: time)
            return nil
        }
    }

    private func startFromWatch(id: UUID, text: String, at time: Date) throws -> VoiceNote? {
        let title = Self.clean(text)
        guard !title.isEmpty, try entry(id: id) == nil else { return nil }

        let note = VoiceNote(recordedAt: time, transcript: title)
        context.insert(note)

        // Something began after it while the phone was out of reach: the watch's event
        // ran until then.
        var later = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.start > time }, sortBy: [SortDescriptor(\.start)])
        later.fetchLimit = 1
        if let next = try context.fetch(later).first {
            let start = Self.wholeMinute(time)
            let end = max(Self.wholeMinute(next.start), start.addingTimeInterval(Self.minimumDuration))
            context.insert(TimeEntry(id: id, start: start, end: end, note: title, source: .typed, voiceNote: note))
        } else {
            try finishRunning(at: time)
            context.insert(TimeEntry(id: id, start: time, note: title, source: .typed, voiceNote: note))
        }
        try context.save()
        return note
    }

    private func stopFromWatch(id: UUID, at time: Date) throws {
        // Already ended (on the phone, or by a later start), or never arrived.
        guard let entry = try entry(id: id), entry.isRunning, time >= entry.start else { return }
        let start = Self.wholeMinute(entry.start)
        entry.start = start
        entry.end = max(Self.wholeMinute(time), start.addingTimeInterval(Self.minimumDuration))
        try context.save()
    }
}
