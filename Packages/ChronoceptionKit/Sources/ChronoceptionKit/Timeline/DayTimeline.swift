import Foundation

/// One day of the log as the timeline shows it: entries in start order, with the
/// stretches nothing was recorded for (空档) between them.
public struct DayTimeline {
    public enum Row: Identifiable {
        case entry(TimeEntry)
        case gap(DateInterval)

        public var id: String {
            switch self {
            case .entry(let entry): entry.id.uuidString
            case .gap(let gap): "gap-\(gap.start.timeIntervalSinceReferenceDate)"
            }
        }

        public var start: Date {
            switch self {
            case .entry(let entry): entry.start
            case .gap(let gap): gap.start
            }
        }
    }

    /// Shorter gaps are not shown: switching from one thing to the next takes a moment.
    public static let minimumGap: TimeInterval = 5 * 60

    public let day: DateInterval
    /// The part of the day that has already happened; nil for a day that has not begun.
    public let window: DateInterval?
    public let rows: [Row]
    /// Gaps of at least the minimum length, oldest first.
    public let gaps: [DateInterval]
    /// Time in `window` covered by at least one entry; overlapping entries count once.
    public let recorded: TimeInterval

    /// Time in `window` that no entry covers, short gaps included.
    public var unrecorded: TimeInterval { (window?.duration ?? 0) - recorded }

    /// Where a new manual entry goes by default: the latest gap, or else the half
    /// hour before the end of the day so far.
    public var suggestedNewEntry: DateInterval {
        if let gap = gaps.last { return gap }
        let end = window?.end ?? day.start
        return DateInterval(start: end.addingTimeInterval(-30 * 60), end: end)
    }

    /// - Parameter entries: the entries that overlap `day`, as `TimeLog.entries(on:)`
    ///   returns them. A running entry counts as lasting until `now`.
    public init(
        day: DateInterval,
        entries: [TimeEntry],
        now: Date,
        minimumGap: TimeInterval = DayTimeline.minimumGap
    ) {
        let windowEnd = min(day.end, now)
        let window = windowEnd > day.start ? DateInterval(start: day.start, end: windowEnd) : nil
        let covered = window.map { Self.covered(by: entries, within: $0, now: now) } ?? []
        let gaps = window.map { Self.uncovered(covered, within: $0) } ?? []

        self.day = day
        self.window = window
        self.gaps = gaps.filter { $0.duration >= minimumGap }
        self.recorded = covered.reduce(0) { $0 + $1.duration }
        self.rows = (entries.map(Row.entry) + self.gaps.map(Row.gap)).sorted(by: Self.isOrderedBefore)
    }

    /// The parts of `window` that entries cover, merged and sorted.
    private static func covered(by entries: [TimeEntry], within window: DateInterval, now: Date) -> [DateInterval] {
        let pieces = entries
            .compactMap { entry -> DateInterval? in
                let start = max(entry.start, window.start)
                let end = min(entry.end ?? now, window.end)
                return end > start ? DateInterval(start: start, end: end) : nil
            }
            .sorted { $0.start < $1.start }

        var merged: [DateInterval] = []
        for piece in pieces {
            if let last = merged.last, piece.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, piece.end))
            } else {
                merged.append(piece)
            }
        }
        return merged
    }

    /// The parts of `window` outside `covered`, which must be merged and sorted.
    private static func uncovered(_ covered: [DateInterval], within window: DateInterval) -> [DateInterval] {
        var gaps: [DateInterval] = []
        var cursor = window.start
        for interval in covered {
            if interval.start > cursor {
                gaps.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if window.end > cursor {
            gaps.append(DateInterval(start: cursor, end: window.end))
        }
        return gaps
    }

    private static func isOrderedBefore(_ lhs: Row, _ rhs: Row) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        switch (lhs, rhs) {
        case (.entry(let a), .entry(let b)): return a.id.uuidString < b.id.uuidString
        case (.entry, .gap): return true
        case (.gap, _): return false
        }
    }
}
