import Foundation

/// What background tidying knows about an event: the words it was started with, and when.
public struct TidyContext: Sendable, Equatable {
    public var text: String
    /// When the event was started, i.e. when the words were written.
    public var startedAt: Date
    public var timeZone: TimeZone

    public init(text: String, startedAt: Date, timeZone: TimeZone) {
        self.text = text
        self.startedAt = startedAt
        self.timeZone = timeZone
    }
}

/// A tidied event: a short title, and an earlier start if the words gave one
/// ("九点就开始了").
public struct TidyResult: Sendable, Equatable {
    public var title: String
    public var start: Date?

    public init(title: String, start: Date? = nil) {
        self.title = title
        self.start = start
    }
}

public enum TidyError: Error, Equatable, Sendable {
    /// The reply held no JSON in the expected shape.
    case unreadableReply
}

/// The instructions sent with each event's words. The reply must be JSON that
/// `TidyResult(reply:context:)` reads.
public enum TidyPrompt {
    public static func system(for context: TidyContext) -> String {
        let written = PromptTime(context.startedAt, in: context.timeZone)
        return """
        你在帮用户整理时间记录。用户开始做一件事时，随手写了一句话，这句话就是这件事的标题。请把它整理成简洁的标题。

        这句话写于 \(written.dateTime)（\(written.weekday)），写下的那一刻开始计时。

        只输出一个 JSON 对象，不要输出任何其他文字：{"title": "标题", "start": "YYYY-MM-DDTHH:mm" 或 null}

        规则：
        1. title 用几个字到十几个字说清在做什么。去掉“开始”“现在”“我要”“准备”这类词和语气词，保留具体内容（书名、课程、项目、人名等）。原句已经简洁就原样返回，不要添加原句里没有的信息。
        2. 只有这句话明确说了更早的开始时间（如“九点就开始了”“半小时前开始的”）时，start 才写那个时间：本地时间，精确到分钟，以写下的那一刻为准换算；只说了几点时，取不晚于那一刻的最近一次。否则 start 为 null。
        """
    }

    public static func user(for context: TidyContext) -> String {
        context.text
    }
}

extension TidyResult {
    /// Reads the reply (see `TidyPrompt`), tolerating thinking, code fences and stray
    /// text around the JSON. A start is kept only if it is earlier than the event's,
    /// within the past day.
    public init(reply: String, context: TidyContext) throws {
        struct Raw: Decodable {
            var title: String?
            var start: String?
        }
        let text = reply.replacing(#/<think>[\s\S]*?</think>/#, with: "")
        guard
            let open = text.firstIndex(of: "{"),
            let close = text.lastIndex(of: "}"),
            open < close,
            let raw = try? JSONDecoder().decode(Raw.self, from: Data(text[open...close].utf8))
        else { throw TidyError.unreadableReply }

        let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let start = raw.start.flatMap { LocalTime.parse($0, in: context.timeZone, notAfter: context.startedAt) }
        let earliest = context.startedAt.addingTimeInterval(-24 * 60 * 60)
        self.init(
            title: title.isEmpty ? context.text : String(title.prefix(60)),
            start: start.flatMap { $0 < TimeLog.wholeMinute(context.startedAt) && $0 > earliest ? $0 : nil }
        )
    }
}

/// Tidies an event's words with MiniMax.
public struct EventTidier: Sendable {
    let client: MiniMaxClient

    public init(client: MiniMaxClient) {
        self.client = client
    }

    public func tidy(_ context: TidyContext) async throws -> TidyResult {
        let reply = try await client.reply(
            system: TidyPrompt.system(for: context),
            user: TidyPrompt.user(for: context)
        )
        return try TidyResult(reply: reply, context: context)
    }
}

/// Times written out for, and read back from, the model, in the user's time zone.
enum LocalTime {
    /// "2026-10-04T09:30" (or with a space, or seconds). A bare "09:30" means the latest
    /// such moment not after `reference`.
    static func parse(_ raw: String, in timeZone: TimeZone, notAfter reference: Date) -> Date? {
        let raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        if let match = raw.firstMatch(of: #/(\d{4})-(\d{1,2})-(\d{1,2})[T ](\d{1,2}):(\d{2})/#) {
            return calendar.date(from: DateComponents(
                year: Int(match.1), month: Int(match.2), day: Int(match.3),
                hour: Int(match.4), minute: Int(match.5)
            ))
        }
        if let match = raw.wholeMatch(of: #/(\d{1,2}):(\d{2})/#) {
            var parts = calendar.dateComponents([.year, .month, .day], from: reference)
            parts.hour = Int(match.1)
            parts.minute = Int(match.2)
            guard let sameDay = calendar.date(from: parts) else { return nil }
            return sameDay > reference ? calendar.date(byAdding: .day, value: -1, to: sameDay) : sameDay
        }
        return nil
    }
}

/// A moment written out for the prompt, in the user's time zone.
struct PromptTime {
    private let parts: DateComponents

    init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
    }

    /// "2026-10-04"
    var date: String {
        String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// "2026-10-04 14:05"
    var dateTime: String {
        "\(date) " + String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// "星期日"
    var weekday: String {
        let names = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        return names[((parts.weekday ?? 1) - 1 + 7) % 7]
    }
}
