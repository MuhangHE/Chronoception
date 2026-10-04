import Foundation

public enum DurationFormat {
    /// Whole minutes, rounded down: "45分钟", "2小时", "1小时25分".
    public static func string(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int((duration / 60).rounded(.down)))
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)分钟"
        case (_, 0): return "\(hours)小时"
        default: return "\(hours)小时\(rest)分"
        }
    }
}
