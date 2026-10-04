import Foundation

/// One block of time, Lyubishchev-style: what you did, from when to when.
public struct TimeEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var start: Date
    public var end: Date?
    public var category: String
    public var note: String
    /// Raw voice transcript this entry was parsed from, if any.
    public var transcript: String?

    public init(
        id: UUID = UUID(),
        start: Date,
        end: Date? = nil,
        category: String,
        note: String = "",
        transcript: String? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.category = category
        self.note = note
        self.transcript = transcript
    }

    /// Length of the entry in seconds; `nil` while it is still running.
    public var duration: TimeInterval? {
        end.map { $0.timeIntervalSince(start) }
    }
}
