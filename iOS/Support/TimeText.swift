import ChronoceptionKit
import Foundation

extension Locale {
    /// Simplified Chinese with a 24-hour clock, so date pickers match the timeline.
    static let chinese24Hour: Locale = {
        var components = Locale.Components(identifier: "zh_CN")
        components.hourCycle = .zeroToTwentyThree
        return Locale(components: components)
    }()
}

/// Date and time text for the Chinese UI. Clock times are always 24-hour.
enum TimeText {
    /// An entry's title, or "未命名" when it has none.
    static func title(of entry: TimeEntry) -> String {
        entry.title.isEmpty ? "未命名" : entry.title
    }

    private static let chinese = Locale.chinese24Hour

    /// "09:05"
    static func clock(_ date: Date) -> String {
        date.formatted(Date.VerbatimFormatStyle(
            format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            timeZone: .current,
            calendar: .current
        ))
    }

    /// "14:05" today, "10月2日 14:05" on other days.
    static func moment(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? clock(date) : "\(monthDay(date)) \(clock(date))"
    }

    /// "10月2日"
    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().locale(chinese))
    }

    /// "今天 10月4日", "昨天 10月3日", "10月2日 周五"
    static func dayTitle(_ day: Date, offset: Int) -> String {
        switch offset {
        case 0: "今天 \(monthDay(day))"
        case -1: "昨天 \(monthDay(day))"
        default: day.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated).locale(chinese))
        }
    }

    /// "09:00 – 10:30". Ending exactly at midnight shows "24:00"; times outside `day`
    /// also show their date; a running entry ends in "进行中".
    static func range(_ start: Date, _ end: Date?, within day: DateInterval) -> String {
        let from = start < day.start ? "\(monthDay(start)) \(clock(start))" : clock(start)
        guard let end else { return "\(from) – 进行中" }
        let to =
            if end == day.end { "24:00" }
            else if end > day.end { "\(monthDay(end)) \(clock(end))" }
            else { clock(end) }
        return "\(from) – \(to)"
    }

    /// Like `range(_:_:within:)`, relative to the day `start` falls on.
    static func range(_ start: Date, _ end: Date?) -> String {
        let day = Calendar.current.dateInterval(of: .day, for: start) ?? DateInterval(start: start, duration: 0)
        return range(start, end, within: day)
    }
}
