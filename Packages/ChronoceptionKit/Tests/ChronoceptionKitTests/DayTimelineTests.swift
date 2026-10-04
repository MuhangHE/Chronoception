import Foundation
import SwiftData
import Testing
@testable import ChronoceptionKit

struct DayTimelineTests {
    let log: TimeLog

    init() throws {
        log = TimeLog(context: ModelContext(try ChronoceptionStore.makeContainer(inMemory: true)))
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        TestDates.date(day, hour, minute)
    }

    @discardableResult
    func entry(_ start: Date, _ end: Date) throws -> TimeEntry {
        try log.addEntry(start: start, end: end, title: "")
    }

    func timeline(day: Int, now: Date) throws -> DayTimeline {
        let interval = TestDates.day(day)
        return DayTimeline(day: interval, entries: try log.entries(overlapping: interval), now: now)
    }

    /// Rows as short strings, e.g. "entry 08:00-09:00" or "gap 09:00-10:00".
    func describe(_ rows: [DayTimeline.Row]) -> [String] {
        rows.map { row in
            switch row {
            case .entry(let entry):
                "entry \(TestDates.clock(entry.start))-\(entry.end.map(TestDates.clock) ?? "now")"
            case .gap(let gap):
                "gap \(TestDates.clock(gap.start))-\(TestDates.clock(gap.end))"
            }
        }
    }

    @Test func anEmptyDayIsOneGapUpToNow() throws {
        let timeline = try timeline(day: 3, now: date(3, 10, 15))

        #expect(describe(timeline.rows) == ["gap 00:00-10:15"])
        #expect(timeline.window == DateInterval(start: date(3, 0), end: date(3, 10, 15)))
        #expect(timeline.recorded == 0)
        #expect(timeline.unrecorded == TimeInterval((10 * 60 + 15) * 60))
    }

    @Test func gapsSitBetweenEntriesAndShortOnesAreLeftOut() throws {
        try entry(date(3, 8), date(3, 9))
        try entry(date(3, 9, 3), date(3, 10))
        try entry(date(3, 10, 30), date(3, 11))

        let timeline = try timeline(day: 3, now: date(3, 12))
        #expect(describe(timeline.rows) == [
            "gap 00:00-08:00",
            "entry 08:00-09:00",
            "entry 09:03-10:00",
            "gap 10:00-10:30",
            "entry 10:30-11:00",
            "gap 11:00-12:00",
        ])
        #expect(timeline.recorded == TimeInterval((60 + 57 + 30) * 60))
        #expect(timeline.unrecorded == TimeInterval((12 * 60 - 147) * 60))
        #expect(Set(timeline.rows.map(\.id)).count == timeline.rows.count)
    }

    @Test func overlappingEntriesCountOnce() throws {
        try entry(date(3, 9), date(3, 11))
        try entry(date(3, 10), date(3, 12))

        let timeline = try timeline(day: 3, now: date(3, 12))
        #expect(describe(timeline.rows) == ["gap 00:00-09:00", "entry 09:00-11:00", "entry 10:00-12:00"])
        #expect(timeline.recorded == TimeInterval(3 * 60 * 60))
    }

    @Test func anEntryCrossingMidnightCountsOnlyItsPartOfTheDay() throws {
        try entry(date(2, 23), date(3, 7))

        let timeline = try timeline(day: 3, now: date(3, 8))
        #expect(describe(timeline.rows) == ["entry 23:00-07:00", "gap 07:00-08:00"])
        #expect(timeline.recorded == TimeInterval(7 * 60 * 60))
    }

    @Test func aRunningEntryCoversUpToNow() throws {
        try log.start(title: "", at: date(3, 9))

        let timeline = try timeline(day: 3, now: date(3, 10, 30))
        #expect(describe(timeline.rows) == ["gap 00:00-09:00", "entry 09:00-now"])
        #expect(timeline.recorded == TimeInterval(90 * 60))
    }

    @Test func aPastDayCoversTheWholeDay() throws {
        try entry(date(2, 12), date(2, 13))

        let timeline = try timeline(day: 2, now: date(3, 10))
        #expect(timeline.window == TestDates.day(2))
        #expect(describe(timeline.rows) == ["gap 00:00-12:00", "entry 12:00-13:00", "gap 13:00-00:00"])
        #expect(timeline.recorded == TimeInterval(60 * 60))
    }

    @Test func aDayThatHasNotBegunIsEmpty() throws {
        let timeline = try timeline(day: 4, now: date(3, 10))
        #expect(timeline.window == nil)
        #expect(timeline.rows.isEmpty)
        #expect(timeline.recorded == 0)
        #expect(timeline.unrecorded == 0)
    }

    @Test func newEntriesGoInTheLatestGap() throws {
        try entry(date(3, 8), date(3, 9))
        #expect(try timeline(day: 3, now: date(3, 12)).suggestedNewEntry
            == DateInterval(start: date(3, 9), end: date(3, 12)))

        try log.start(title: "", at: date(3, 9))
        #expect(try timeline(day: 3, now: date(3, 12)).suggestedNewEntry
            == DateInterval(start: date(3, 0), end: date(3, 8)))
    }

    @Test func withoutGapsNewEntriesGoInTheLastHalfHour() throws {
        try entry(date(3, 0), date(3, 12))
        #expect(try timeline(day: 3, now: date(3, 12)).suggestedNewEntry
            == DateInterval(start: date(3, 11, 30), end: date(3, 12)))
    }
}
