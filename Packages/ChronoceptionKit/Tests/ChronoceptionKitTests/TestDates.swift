import Foundation

/// A fixed New York calendar and October 2026 dates, so tests do not depend on the
/// machine's time zone.
enum TestDates {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// 2026-10-`day` at `hour`:`minute`:`second`.
    static func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second
        ))!
    }

    /// All of 2026-10-`day`.
    static func day(_ day: Int) -> DateInterval {
        calendar.dateInterval(of: .day, for: date(day, 12))!
    }

    /// "HH:mm" in the test time zone.
    static func clock(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }
}
