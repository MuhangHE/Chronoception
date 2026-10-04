import Foundation
import SwiftData
import Testing
@testable import ChronoceptionKit

struct TimeLogTests {
    let log: TimeLog
    let calendar = TestDates.calendar

    init() throws {
        log = TimeLog(context: ModelContext(try ChronoceptionStore.makeContainer(inMemory: true)))
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        TestDates.date(day, hour, minute, second)
    }

    func allEntries() throws -> [TimeEntry] {
        try log.allEntries()
    }

    // MARK: - Starting and ending events

    @Test func startingAnEventKeepsItsWordsAndEndsTheRunningOne() throws {
        let paper = try log.startEvent("  写论文第三章 \n", at: date(3, 9))
        #expect(paper.isRunning)
        #expect(paper.title == "写论文第三章")
        #expect(paper.source == .typed)
        #expect(paper.voiceNote?.transcript == "写论文第三章")
        #expect(paper.voiceNote?.status == .pending)
        #expect(paper.elapsed(at: date(3, 9, 30)) == 30 * 60)

        let reading = try log.startEvent("看文献", at: date(3, 10))
        #expect(paper.end == date(3, 10))
        #expect(paper.duration == TimeInterval(60 * 60))
        #expect(try log.runningEntry()?.id == reading.id)
        #expect(try allEntries().filter(\.isRunning).count == 1)

        try log.stopRunning(at: date(3, 11))
        #expect(reading.end == date(3, 11))
        #expect(try log.runningEntry() == nil)
    }

    @Test func anEventNeedsWords() {
        #expect(throws: TimeLogError.emptyTitle) { try log.startEvent("   ") }
    }

    @Test func aRunningEventKeepsItsExactStartUntilItEnds() throws {
        let event = try log.startEvent("开会", at: date(3, 9, 0, 40))
        #expect(event.start == date(3, 9, 0, 40))

        try log.stopRunning(at: date(3, 9, 45, 20))
        #expect(event.start == date(3, 9))
        #expect(event.end == date(3, 9, 45))
    }

    @Test func endingWithinAMinuteStillKeepsTheEvent() throws {
        let quick = try log.startEvent("测试", at: date(3, 9, 0, 10))
        try log.stopRunning(at: date(3, 9, 0, 50))

        #expect(try allEntries().map(\.id) == [quick.id])
        #expect(quick.start == date(3, 9))
        #expect(quick.end == date(3, 9, 1))
    }

    @Test func switchingWithinAMinuteKeepsBoth() throws {
        let first = try log.startEvent("看文献", at: date(3, 9))
        let second = try log.startEvent("写论文", at: date(3, 9, 0, 40))

        #expect(try allEntries().map(\.id) == [first.id, second.id])
        #expect(first.end == date(3, 9, 1))
        #expect(second.isRunning)
    }

    @Test func cannotStartBeforeTheRunningEvent() throws {
        let running = try log.start(title: "写论文", at: date(3, 10))
        #expect(throws: TimeLogError.startsBeforeRunningEntry) {
            try log.start(title: "看文献", at: date(3, 9))
        }
        #expect(running.isRunning)
    }

    // MARK: - Finished entries

    @Test func entriesMustEndAfterTheyStart() throws {
        #expect(throws: TimeLogError.invalidInterval) {
            try log.addEntry(start: date(3, 10), end: date(3, 10), title: "")
        }
        #expect(throws: TimeLogError.invalidInterval) {
            try log.addEntry(start: date(3, 10), end: date(3, 9), title: "")
        }
        #expect(throws: TimeLogError.invalidInterval) {
            try log.addEntry(start: date(3, 11, 0, 10), end: date(3, 11, 0, 50), title: "")
        }
        #expect(try allEntries().isEmpty)
    }

    @Test func finishedEntriesAreKeptToTheMinute() throws {
        let entry = try log.addEntry(start: date(3, 10, 0, 10), end: date(3, 10, 45, 50), title: " 早读 ")
        #expect(entry.start == date(3, 10))
        #expect(entry.end == date(3, 10, 45))
        #expect(entry.title == "早读")
        #expect(entry.source == .manual)
    }

    @Test func updateValidatesTheInterval() throws {
        let entry = try log.addEntry(start: date(3, 9), end: date(3, 10), title: "上课")
        #expect(throws: TimeLogError.invalidInterval) {
            try log.update(entry, start: date(3, 11), end: date(3, 10), title: "")
        }
        #expect(throws: TimeLogError.invalidInterval) {
            try log.update(entry, start: date(3, 9), end: nil, title: "")
        }

        try log.update(entry, start: date(3, 8, 0, 30), end: date(3, 10), title: " 早读 ")
        #expect(entry.start == date(3, 8))
        #expect(entry.duration == TimeInterval(2 * 60 * 60))
        #expect(entry.title == "早读")
    }

    @Test func splitCutsAnEntryInTwo() throws {
        let entry = try log.addEntry(start: date(3, 9), end: date(3, 12), title: "两节课")

        let second = try log.split(entry, at: date(3, 10, 30, 30))
        #expect(entry.end == date(3, 10, 30))
        #expect(second.start == date(3, 10, 30))
        #expect(second.end == date(3, 12))
        #expect(second.title == "两节课")

        #expect(throws: TimeLogError.splitPointOutsideEntry) { try log.split(entry, at: date(3, 9)) }
        #expect(throws: TimeLogError.splitPointOutsideEntry) { try log.split(entry, at: date(3, 11)) }
    }

    @Test func splittingARunningEntryKeepsTheSecondPartRunning() throws {
        let running = try log.start(title: "写论文", at: date(3, 9))
        let second = try log.split(running, at: date(3, 10), now: date(3, 11))

        #expect(running.end == date(3, 10))
        #expect(second.isRunning)
        #expect(try log.runningEntry()?.id == second.id)
        #expect(throws: TimeLogError.splitPointOutsideEntry) {
            try log.split(second, at: date(3, 12), now: date(3, 11))
        }
    }

    @Test func deleteRemovesTheEntry() throws {
        let entry = try log.addEntry(start: date(3, 9), end: date(3, 10), title: "")
        try log.delete(entry)
        #expect(try allEntries().isEmpty)
    }

    // MARK: - Queries

    @Test func entriesOnADayIncludeThoseCrossingMidnightAndTheRunningOne() throws {
        let sleep = try log.addEntry(start: date(2, 23), end: date(3, 7), title: "睡觉")
        let lecture = try log.addEntry(start: date(3, 9), end: date(3, 10), title: "上课")
        let running = try log.start(title: "写论文", at: date(3, 11))
        try log.addEntry(start: date(1, 9), end: date(1, 10), title: "")

        #expect(try log.entries(on: date(3, 12), calendar: calendar).map(\.id) == [sleep.id, lecture.id, running.id])
        #expect(try log.entries(on: date(2, 12), calendar: calendar).map(\.id) == [sleep.id])
    }

    @Test func overlappingEntriesAreFound() throws {
        let morning = try log.addEntry(start: date(3, 9), end: date(3, 10), title: "")
        try log.addEntry(start: date(3, 10), end: date(3, 11), title: "")

        let overlaps = try log.entries(overlapping: DateInterval(start: date(3, 9, 30), end: date(3, 10)))
        #expect(overlaps.map(\.id) == [morning.id])
    }

    // MARK: - Older data

    @Test func categoryEntriesGetTheCategoryNameAsTitle() throws {
        let research = ActivityCategory(name: "科研")
        log.context.insert(research)
        let tapped = TimeEntry(start: date(3, 9), end: date(3, 10), category: research, source: .quickStart)
        let titled = TimeEntry(start: date(3, 10), end: date(3, 11), category: research, note: "写论文")
        let bare = TimeEntry(start: date(3, 11), end: date(3, 12))
        [tapped, titled, bare].forEach(log.context.insert)
        try log.context.save()

        #expect(tapped.title == "科研")
        #expect(try log.adoptCategoryNamesAsTitles() == 1)
        #expect(tapped.note == "科研")
        #expect(titled.note == "写论文")
        #expect(bare.note == "")
        #expect(try log.adoptCategoryNamesAsTitles() == 0)
    }

    // MARK: - Persistence

    @Test func dataSurvivesReopeningTheStore() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Chronoception.store")

        do {
            let log = TimeLog(context: ModelContext(try ChronoceptionStore.makeContainer(url: url)))
            try log.addEntry(start: date(3, 9), end: date(3, 10), title: "组会")
        }

        let reopened = TimeLog(context: ModelContext(try ChronoceptionStore.makeContainer(url: url)))
        let entry = try #require(reopened.entries(on: date(3, 12), calendar: calendar).first)
        #expect(entry.title == "组会")
    }
}
