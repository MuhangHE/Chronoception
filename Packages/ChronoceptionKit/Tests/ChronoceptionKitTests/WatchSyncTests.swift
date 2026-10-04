import Foundation
import SwiftData
import Testing
@testable import ChronoceptionKit

struct WatchSyncTests {
    let log: TimeLog

    init() throws {
        log = TimeLog(context: ModelContext(try ChronoceptionStore.makeContainer(inMemory: true)))
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        TestDates.date(day, hour, minute, second)
    }

    // MARK: - Messages

    @Test func commandsAndSnapshotsSurviveTheTrip() throws {
        let id = UUID()
        for command in [WatchCommand.start(id: id, text: "写论文", at: date(4, 9)), .stop(id: id, at: date(4, 10))] {
            #expect(WatchMessage.command(from: try WatchMessage.payload(for: command)) == command)
        }
        let snapshot = WatchSnapshot(running: .init(id: id, title: "写论文", start: date(4, 9, 0, 30)), madeAt: date(4, 9, 1))
        #expect(WatchMessage.snapshot(from: try WatchMessage.payload(for: snapshot)) == snapshot)
        #expect(WatchMessage.command(from: ["other": 1]) == nil)
        #expect(WatchMessage.snapshot(from: [:]) == nil)
    }

    // MARK: - Starting from the watch

    @Test func aStartFromTheWatchRunsOnThePhone() throws {
        let paper = try log.startEvent("看文献", at: date(4, 8))
        let id = UUID()

        let note = try log.apply(.start(id: id, text: " 写论文 ", at: date(4, 9, 0, 20)))

        let started = try #require(try log.entry(id: id))
        #expect(started.isRunning)
        #expect(started.start == date(4, 9, 0, 20))
        #expect(started.title == "写论文")
        #expect(started.source == .typed)
        #expect(note?.id == started.voiceNote?.id)
        #expect(paper.end == date(4, 9))
        #expect(try log.watchSnapshot(madeAt: date(4, 9, 1)) == WatchSnapshot(
            running: .init(id: id, title: "写论文", start: date(4, 9, 0, 20)), madeAt: date(4, 9, 1)
        ))
    }

    @Test func aStartDeliveredTwiceCountsOnce() throws {
        let command = WatchCommand.start(id: UUID(), text: "写论文", at: date(4, 9))
        try log.apply(command)
        #expect(try log.apply(command) == nil)
        #expect(try log.allEntries().count == 1)
    }

    @Test func aLateStartEndsWhenTheNextThingBegan() throws {
        // On the watch at 9:00, but the phone only hears of it after starting something at 9:30.
        let later = try log.startEvent("开会", at: date(4, 9, 30))
        let id = UUID()

        try log.apply(.start(id: id, text: "写论文", at: date(4, 9)))

        let late = try #require(try log.entry(id: id))
        #expect(late.start == date(4, 9))
        #expect(late.end == date(4, 9, 30))
        #expect(later.isRunning)
    }

    // MARK: - Stopping from the watch

    @Test func aStopFromTheWatchEndsThatEvent() throws {
        let id = UUID()
        try log.apply(.start(id: id, text: "写论文", at: date(4, 9, 0, 40)))
        try log.apply(.stop(id: id, at: date(4, 9, 0, 50)))

        let event = try #require(try log.entry(id: id))
        #expect(event.start == date(4, 9))
        #expect(event.end == date(4, 9, 1))
        #expect(try log.watchSnapshot().running == nil)
    }

    @Test func staleStopsChangeNothing() throws {
        let id = UUID()
        try log.apply(.start(id: id, text: "写论文", at: date(4, 9)))
        let next = try log.startEvent("开会", at: date(4, 10))

        try log.apply(.stop(id: id, at: date(4, 10, 30)))
        try log.apply(.stop(id: UUID(), at: date(4, 10, 30)))

        #expect(try log.entry(id: id)?.end == date(4, 10))
        #expect(next.isRunning)
    }
}
