import ChronoceptionKit
import Foundation

/// Which MiniMax platform and model to use. The key itself is in `APIKeyStore`.
enum ParserSettings {
    static let regionKey = "minimax.region"
    static let modelKey = "minimax.model"

    static var region: MiniMaxRegion {
        UserDefaults.standard.string(forKey: regionKey).flatMap(MiniMaxRegion.init(rawValue:)) ?? .china
    }

    static var model: String {
        let model = UserDefaults.standard.string(forKey: modelKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return model.isEmpty ? MiniMaxClient.defaultModel : model
    }

    /// A client with the saved settings; throws `MiniMaxError.missingAPIKey` until a key is saved.
    static func client() throws -> MiniMaxClient {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakeParser") { return FakeMiniMax.client }
        #endif
        guard let key = APIKeyStore.load() else { throw MiniMaxError.missingAPIKey }
        return MiniMaxClient(apiKey: key, region: region, model: model)
    }
}

#if DEBUG
/// Launch with `-fakeParser` to try tidying without a key or network: it drops filler
/// words such as "现在开始", and reads "半小时前" as a start half an hour back.
enum FakeMiniMax {
    static var client: MiniMaxClient {
        MiniMaxClient(apiKey: "fake", region: .china, model: "fake") { request in
            try await Task.sleep(for: .milliseconds(800))
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            let words = (body?["messages"] as? [[String: String]])?.last?["content"] ?? ""
            var title = words
            for filler in ["嗯", "现在", "我要", "开始", "半小时前就", "半小时前", "了"] {
                title = title.replacingOccurrences(of: filler, with: "")
            }
            var start = "null"
            if words.contains("半小时前") {
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: .now - 1800)
                start = String(
                    format: "\"%04d-%02d-%02dT%02d:%02d\"",
                    parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0
                )
            }
            let content = #"{"title": "\#(title)", "start": \#(start)}"#
            let reply: [String: Any] = [
                "choices": [["message": ["role": "assistant", "content": content]]],
                "base_resp": ["status_code": 0, "status_msg": ""],
            ]
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (try JSONSerialization.data(withJSONObject: reply), response)
        }
    }
}
#endif
