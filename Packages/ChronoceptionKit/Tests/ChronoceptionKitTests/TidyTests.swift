import Foundation
import SwiftData
import Testing
@testable import ChronoceptionKit

struct TidyTests {
    let log: TimeLog

    init() throws {
        log = TimeLog(context: ModelContext(try ChronoceptionStore.makeContainer(inMemory: true)))
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        TestDates.date(day, hour, minute, second)
    }

    func context(_ text: String = "嗯现在开始写论文", at startedAt: Date = TestDates.date(4, 14, 5, 30)) -> TidyContext {
        TidyContext(text: text, startedAt: startedAt, timeZone: TestDates.calendar.timeZone)
    }

    // MARK: - Prompt

    @Test func thePromptSaysWhenTheWordsWereWritten() {
        let prompt = TidyPrompt.system(for: context())
        #expect(prompt.contains("这句话写于 2026-10-04 14:05（星期日）"))
        #expect(prompt.contains(#"{"title": "标题", "start": "YYYY-MM-DDTHH:mm" 或 null}"#))
        #expect(TidyPrompt.user(for: context()) == "嗯现在开始写论文")
    }

    // MARK: - Reading the reply

    @Test func readsTheTitleDespiteThinkingAndFences() throws {
        let reply = """
        <think>去掉语气词</think>
        ```json
        {"title": " 写论文 ", "start": null}
        ```
        """
        #expect(try TidyResult(reply: reply, context: context()) == TidyResult(title: "写论文"))
    }

    @Test func anEmptyTitleKeepsTheWords() throws {
        let result = try TidyResult(reply: #"{"title": "", "start": null}"#, context: context())
        #expect(result.title == "嗯现在开始写论文")
    }

    @Test func rejectsRepliesWithoutJSON() {
        #expect(throws: TidyError.unreadableReply) {
            try TidyResult(reply: "写论文", context: context())
        }
    }

    @Test func keepsOnlyAnEarlierStartWithinADay() throws {
        let at = date(4, 9, 30, 20)
        func start(_ raw: String) throws -> Date? {
            try TidyResult(reply: #"{"title": "看文献", "start": "\#(raw)"}"#, context: context("九点就开始看文献了", at: at)).start
        }
        #expect(try start("2026-10-04T09:00") == date(4, 9))
        #expect(try start("09:00") == date(4, 9))
        #expect(try start("2026-10-04T09:30") == nil)
        #expect(try start("2026-10-04T10:00") == nil)
        #expect(try start("2026-10-02T09:00") == nil)
        #expect(try start("早上") == nil)
        #expect(try start("23:00") == date(3, 23))
    }

    // MARK: - Applying it

    @Test func theTitleIsReplacedUnlessTheUserChangedIt() throws {
        let tidied = try log.startEvent("嗯现在开始写论文", at: date(4, 14))
        let edited = try log.startEvent("开会", at: date(4, 15))
        try log.update(edited, start: edited.start, end: nil, title: "组会")

        try log.apply(TidyResult(title: "写论文"), to: #require(tidied.voiceNote))
        try log.apply(TidyResult(title: "开个会"), to: #require(edited.voiceNote))

        #expect(tidied.title == "写论文")
        #expect(tidied.voiceNote?.status == .parsed)
        #expect(edited.title == "组会")
        #expect(try log.notesWaitingForTidy().isEmpty)
    }

    @Test func anEarlierStartAlsoMovesTheEndOfThePreviousEvent() throws {
        let reading = try log.startEvent("看文献", at: date(4, 8))
        let paper = try log.startEvent("九点就开始写论文了", at: date(4, 9, 30, 15))
        #expect(reading.end == date(4, 9, 30))

        try log.apply(TidyResult(title: "写论文", start: date(4, 9)), to: #require(paper.voiceNote))

        #expect(paper.start == date(4, 9))
        #expect(paper.isRunning)
        #expect(reading.end == date(4, 9))
    }

    @Test func anEarlierStartNeverSwallowsThePreviousEvent() throws {
        let reading = try log.startEvent("看文献", at: date(4, 9, 10))
        let paper = try log.startEvent("八点就开始写论文了", at: date(4, 9, 30))

        try log.apply(TidyResult(title: "写论文", start: date(4, 8)), to: #require(paper.voiceNote))

        #expect(reading.start == date(4, 9, 10))
        #expect(reading.end == date(4, 9, 11))
        #expect(paper.start == date(4, 9, 11))
    }

    @Test func aStartTheUserChangedIsLeftAlone() throws {
        let paper = try log.startEvent("九点就开始写论文了", at: date(4, 9, 30))
        try log.update(paper, start: date(4, 9, 15), end: nil, title: paper.note)

        try log.apply(TidyResult(title: "写论文", start: date(4, 9)), to: #require(paper.voiceNote))
        #expect(paper.start == date(4, 9, 15))
    }

    // MARK: - Waiting notes

    @Test func failedNotesKeepWaiting() throws {
        let event = try log.startEvent("写论文", at: date(4, 9))
        let note = try #require(event.voiceNote)
        let orphan = VoiceNote(recordedAt: date(4, 8), transcript: "旧的一句话")
        log.context.insert(orphan)
        try log.context.save()

        try log.recordFailure(note, message: "网络不可用")
        #expect(note.status == .failed)
        #expect(note.lastError == "网络不可用")
        #expect(note.attemptCount == 1)
        #expect(try log.notesWaitingForTidy().map(\.id) == [note.id])
        #expect(try log.voiceNote(id: note.id)?.id == note.id)
        #expect(log.tidyContext(for: note).text == "写论文")
    }
}
