#if DEBUG
import ChronoceptionKit
import Foundation

/// A believable morning for screenshots and previews. Launch a Debug build with
/// `-demo` and the app shows it from an in-memory log, leaving the real one alone.
enum DemoData {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    /// Fills the hours before `now`: one gap is left open for backfilling, and the
    /// last event is still running.
    static func fill(_ log: TimeLog, now: Date = .now) {
        func ago(_ hours: Int, _ minutes: Int) -> Date {
            now.addingTimeInterval(-TimeInterval((hours * 60 + minutes) * 60))
        }
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let bedtime = calendar.date(bySettingHour: 23, minute: 40, second: 0, of: yesterday) ?? ago(12, 0)

        do {
            try log.addEntry(start: bedtime, end: ago(5, 10), title: "睡觉")
            try log.addEntry(start: ago(5, 10), end: ago(4, 40), title: "早饭")
            try log.addEntry(start: ago(4, 40), end: ago(4, 10), title: "去实验室")
            try log.addEntry(start: ago(4, 10), end: ago(2, 45), title: "读文献：注意力机制综述")
            try log.addEntry(start: ago(2, 45), end: ago(2, 25), title: "回邮件")
            try log.addEntry(start: ago(2, 0), end: ago(0, 55), title: "组会")
            try log.start(title: "写论文第三章", at: ago(0, 55), source: .typed)
        } catch {
            print("Filling the demo log failed: \(error)")
        }
    }
}
#endif
