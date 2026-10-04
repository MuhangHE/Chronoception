import Foundation
import SwiftData

extension TimeLog {
    public func voiceNote(id: UUID) throws -> VoiceNote? {
        var descriptor = FetchDescriptor<VoiceNote>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Notes whose events still wait to be tidied, including failed attempts, oldest first.
    public func notesWaitingForTidy() throws -> [VoiceNote] {
        let done = VoiceNoteStatus.parsed.rawValue
        return try context.fetch(FetchDescriptor<VoiceNote>(
            predicate: #Predicate { $0.statusRaw != done },
            sortBy: [SortDescriptor(\.recordedAt)]
        ))
        .filter { !$0.entries.isEmpty }
    }

    public func tidyContext(for note: VoiceNote, timeZone: TimeZone = .current) -> TidyContext {
        TidyContext(text: note.transcript, startedAt: note.recordedAt, timeZone: timeZone)
    }

    /// Gives the event made from `note` its tidied title and, if the words said so, its
    /// earlier start. Whatever the user has changed by hand since is left alone.
    public func apply(_ result: TidyResult, to note: VoiceNote) throws {
        if let entry = note.entries.first {
            if entry.note == note.transcript {
                entry.note = Self.clean(result.title)
            }
            if let start = result.start, Self.wholeMinute(entry.start) == Self.wholeMinute(note.recordedAt) {
                try moveStart(of: entry, earlierTo: start)
            }
        }
        note.status = .parsed
        note.lastError = nil
        try context.save()
    }

    /// Keeps a note waiting, with the reason the last attempt failed.
    public func recordFailure(_ note: VoiceNote, message: String) throws {
        note.status = .failed
        note.lastError = message
        note.attemptCount += 1
        try context.save()
    }

    /// Moves an event's start earlier. The event it took over from, which ended when
    /// this one began, now ends at the new start, but keeps at least a minute.
    private func moveStart(of entry: TimeEntry, earlierTo time: Date) throws {
        let began = Self.wholeMinute(entry.start)
        var start = Self.wholeMinute(time)
        guard start < began else { return }

        let lookBack = DateInterval(start: began.addingTimeInterval(-24 * 60 * 60), end: began)
        let previous = try entries(overlapping: lookBack)
            .filter { other in
                guard other.id != entry.id, let end = other.end else { return false }
                return other.start < began && end >= began && end <= began.addingTimeInterval(Self.minimumDuration)
            }
            .max { $0.start < $1.start }

        if let previous {
            start = max(start, Self.wholeMinute(previous.start).addingTimeInterval(Self.minimumDuration))
            guard start < began else { return }
            previous.end = start
        }
        entry.start = start
    }
}
