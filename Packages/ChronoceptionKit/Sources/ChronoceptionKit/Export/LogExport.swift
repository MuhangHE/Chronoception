import Foundation

/// The whole log as files to keep or open elsewhere: JSON with everything, CSV for
/// spreadsheets. Times are local, with their UTC offset in JSON.
public enum LogExport {
    public static func json(_ entries: [TimeEntry], exportedAt: Date, timeZone: TimeZone) throws -> Data {
        struct Record: Encodable {
            let id: String
            let title: String
            let start: String
            let end: String?
            let minutes: Int?
            let source: String
            let originalText: String?
            let createdAt: String
        }
        struct File: Encodable {
            let app: String
            let exportedAt: String
            let timeZone: String
            let entries: [Record]
        }

        let file = File(
            app: "Chronoception",
            exportedAt: iso(exportedAt, timeZone),
            timeZone: timeZone.identifier,
            entries: entries.map { entry in
                Record(
                    id: entry.id.uuidString,
                    title: entry.title,
                    start: iso(entry.start, timeZone),
                    end: entry.end.map { iso($0, timeZone) },
                    minutes: entry.duration.map { Int(($0 / 60).rounded(.down)) },
                    source: entry.source.rawValue,
                    originalText: entry.voiceNote?.transcript,
                    createdAt: iso(entry.createdAt, timeZone)
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }

    /// With a byte-order mark, so Excel reads the Chinese correctly.
    public static func csv(_ entries: [TimeEntry], timeZone: TimeZone) -> String {
        let header = ["标题", "开始", "结束", "时长（分钟）", "原文"]
        let rows = entries.map { entry in
            [
                entry.title,
                local(entry.start, timeZone),
                entry.end.map { local($0, timeZone) } ?? "",
                entry.duration.map { String(Int(($0 / 60).rounded(.down))) } ?? "",
                entry.voiceNote?.transcript ?? "",
            ]
        }
        let lines = ([header] + rows).map { $0.map(quoted).joined(separator: ",") }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// A field quoted when it holds a comma, quote or line break.
    static func quoted(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// "2026-10-04T09:30:00-04:00"
    static func iso(_ date: Date, _ timeZone: TimeZone) -> String {
        let offset = timeZone.secondsFromGMT(for: date) / 60
        let sign = offset < 0 ? "-" : "+"
        return local(date, timeZone, separator: "T", seconds: true)
            + String(format: "%@%02d:%02d", sign, abs(offset) / 60, abs(offset) % 60)
    }

    /// "2026-10-04 09:30"
    static func local(_ date: Date, _ timeZone: TimeZone, separator: String = " ", seconds: Bool = false) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let p = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let day = String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
        let time = seconds
            ? String(format: "%02d:%02d:%02d", p.hour ?? 0, p.minute ?? 0, p.second ?? 0)
            : String(format: "%02d:%02d", p.hour ?? 0, p.minute ?? 0)
        return day + separator + time
    }
}
