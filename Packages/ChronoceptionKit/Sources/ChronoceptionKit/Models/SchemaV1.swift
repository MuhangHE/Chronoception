import Foundation
import SwiftData

public typealias ActivityCategory = SchemaV1.ActivityCategory
public typealias TimeEntry = SchemaV1.TimeEntry
public typealias VoiceNote = SchemaV1.VoiceNote

/// Lyubishchev's split of working time.
public enum CategoryKind: Int, CaseIterable, Sendable {
    /// 第一类：核心工作
    case primary = 1
    /// 第二类：其他工作
    case secondary = 2
}

public enum EntrySource: String, Sendable {
    case manual
    case quickStart
    case voice
    /// Typed into the start bar.
    case typed
}

public enum VoiceNoteStatus: String, Sendable {
    case pending
    case parsed
    case failed
}

/// First on-device schema. Real data lives in it, so once shipped, change stored
/// properties only by adding `SchemaV2` and a stage in `ChronoceptionMigrationPlan`.
/// Computed properties can change freely. Categories are no longer used by the app,
/// but stay in the schema so no migration is needed.
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [ActivityCategory.self, TimeEntry.self, VoiceNote.self]
    }

    @Model
    public final class ActivityCategory {
        @Attribute(.unique) public var id: UUID
        public var name: String
        /// Raw `CategoryKind`; nil for time that is neither kind of work (sleep, meals, …).
        public var kindRaw: Int?
        public var sortOrder: Int
        /// Archived categories are hidden from pickers but keep their past entries.
        public var isArchived: Bool
        public var createdAt: Date

        @Relationship(deleteRule: .nullify, inverse: \TimeEntry.category)
        public var entries: [TimeEntry]

        public init(
            id: UUID = UUID(),
            name: String,
            kind: CategoryKind? = nil,
            sortOrder: Int = 0,
            isArchived: Bool = false,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.kindRaw = kind?.rawValue
            self.sortOrder = sortOrder
            self.isArchived = isArchived
            self.createdAt = createdAt
            self.entries = []
        }

        public var kind: CategoryKind? {
            get { kindRaw.flatMap(CategoryKind.init(rawValue:)) }
            set { kindRaw = newValue?.rawValue }
        }
    }

    /// One block of time: what you did, from when to when.
    @Model
    public final class TimeEntry {
        @Attribute(.unique) public var id: UUID
        public var start: Date
        /// nil while the activity is still running.
        public var end: Date?
        /// nil means 未分类.
        public var category: ActivityCategory?
        public var note: String
        public var sourceRaw: String
        public var createdAt: Date
        /// The voice note this entry was parsed from, if any.
        public var voiceNote: VoiceNote?

        public init(
            id: UUID = UUID(),
            start: Date,
            end: Date? = nil,
            category: ActivityCategory? = nil,
            note: String = "",
            source: EntrySource = .manual,
            voiceNote: VoiceNote? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.start = start
            self.end = end
            self.category = category
            self.note = note
            self.sourceRaw = source.rawValue
            self.voiceNote = voiceNote
            self.createdAt = createdAt
        }

        public var source: EntrySource {
            get { EntrySource(rawValue: sourceRaw) ?? .manual }
            set { sourceRaw = newValue.rawValue }
        }

        /// What the entry is called. Titles live in `note`; entries made by tapping a
        /// category before categories were dropped fall back to its name.
        public var title: String {
            note.isEmpty ? (category?.name ?? "") : note
        }

        public var isRunning: Bool { end == nil }

        /// Length in seconds; nil while running.
        public var duration: TimeInterval? {
            end.map { $0.timeIntervalSince(start) }
        }

        /// Length so far, counting a running entry up to `now`.
        public func elapsed(at now: Date) -> TimeInterval {
            (end ?? now).timeIntervalSince(start)
        }
    }

    /// The words an entry was started with, kept as typed. `status` tracks whether
    /// they have been tidied into the entry's title yet.
    @Model
    public final class VoiceNote {
        @Attribute(.unique) public var id: UUID
        /// When it was spoken; relative times such as "半小时前" are resolved against this.
        public var recordedAt: Date
        public var transcript: String
        public var statusRaw: String
        public var lastError: String?
        public var attemptCount: Int

        @Relationship(deleteRule: .nullify, inverse: \TimeEntry.voiceNote)
        public var entries: [TimeEntry]

        public init(
            id: UUID = UUID(),
            recordedAt: Date,
            transcript: String,
            status: VoiceNoteStatus = .pending
        ) {
            self.id = id
            self.recordedAt = recordedAt
            self.transcript = transcript
            self.statusRaw = status.rawValue
            self.lastError = nil
            self.attemptCount = 0
            self.entries = []
        }

        public var status: VoiceNoteStatus {
            get { VoiceNoteStatus(rawValue: statusRaw) ?? .pending }
            set { statusRaw = newValue.rawValue }
        }
    }
}
