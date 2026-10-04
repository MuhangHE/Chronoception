import Foundation
import Testing
@testable import ChronoceptionKit

private let minute: TimeInterval = 60
private let hour: TimeInterval = 60 * minute

private let cases: [(TimeInterval, String)] = [
    (0, "0分钟"),
    (59, "0分钟"),
    (-30, "0分钟"),
    (45 * minute, "45分钟"),
    (hour, "1小时"),
    (hour + 25 * minute + 59, "1小时25分"),
    (25 * hour, "25小时"),
]

@Test(arguments: cases)
func durationsShowWholeMinutes(seconds: TimeInterval, expected: String) {
    #expect(DurationFormat.string(seconds) == expected)
}
