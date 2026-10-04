import Foundation
import Testing
@testable import ChronoceptionKit

@Test func durationIsEndMinusStart() {
    let start = Date(timeIntervalSince1970: 0)
    let entry = TimeEntry(start: start, end: start.addingTimeInterval(1800), category: "Reading")
    #expect(entry.duration == 1800)
}

@Test func runningEntryHasNoDuration() {
    let entry = TimeEntry(start: .now, category: "Reading")
    #expect(entry.duration == nil)
}

@Test func roundTripsThroughJSON() throws {
    let entry = TimeEntry(start: Date(timeIntervalSince1970: 0), category: "Writing", transcript: "started writing")
    let data = try JSONEncoder().encode(entry)
    #expect(try JSONDecoder().decode(TimeEntry.self, from: data) == entry)
}
