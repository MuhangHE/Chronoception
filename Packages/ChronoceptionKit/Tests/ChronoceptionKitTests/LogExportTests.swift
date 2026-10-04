import Foundation
import SwiftData
import Testing
@testable import ChronoceptionKit

struct LogExportTests {
    let log: TimeLog
    let timeZone = TestDates.calendar.timeZone

    init() throws {
        log = TimeLog(context: ModelContext(try ChronoceptionStore.makeContainer(inMemory: true)))
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        TestDates.date(day, hour, minute)
    }

    @Test func jsonHoldsEveryEntryWithLocalTimes() throws {
        try log.addEntry(start: date(3, 9), end: date(3, 10), title: "上课")
        try log.startEvent("写论文", at: date(3, 11))

        let data = try LogExport.json(log.allEntries(), exportedAt: date(3, 12), timeZone: timeZone)
        let file = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(file["app"] as? String == "Chronoception")
        #expect(file["exportedAt"] as? String == "2026-10-03T12:00:00-04:00")
        #expect(file["timeZone"] as? String == "America/New_York")

        let entries = try #require(file["entries"] as? [[String: Any]])
        #expect(entries.count == 2)
        #expect(entries[0]["title"] as? String == "上课")
        #expect(entries[0]["start"] as? String == "2026-10-03T09:00:00-04:00")
        #expect(entries[0]["end"] as? String == "2026-10-03T10:00:00-04:00")
        #expect(entries[0]["minutes"] as? Int == 60)
        #expect(entries[0]["source"] as? String == "manual")
        #expect(entries[1]["originalText"] as? String == "写论文")
        #expect(entries[1]["source"] as? String == "typed")
        #expect(entries[1]["end"] == nil)
        #expect(entries[1]["minutes"] == nil)
    }

    @Test func csvOpensInSpreadsheets() throws {
        try log.addEntry(start: date(3, 9), end: date(3, 10, 30), title: "读《枪炮, 病菌与钢铁》")
        try log.addEntry(start: date(3, 11), end: date(3, 12), title: "他说\"好\"")
        try log.startEvent("写论文", at: date(3, 13))

        let csv = LogExport.csv(try log.allEntries(), timeZone: timeZone)
        #expect(csv.hasPrefix("\u{FEFF}标题,开始,结束,时长（分钟）,原文\r\n"))
        let lines = csv.dropFirst().components(separatedBy: "\r\n")
        #expect(lines[1] == "\"读《枪炮, 病菌与钢铁》\",2026-10-03 09:00,2026-10-03 10:30,90,")
        #expect(lines[2] == "\"他说\"\"好\"\"\",2026-10-03 11:00,2026-10-03 12:00,60,")
        #expect(lines[3] == "写论文,2026-10-03 13:00,,,写论文")
        #expect(lines[4] == "")
    }
}
