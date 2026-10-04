import Foundation

/// MiniMax runs separate platforms with separate API keys.
public enum MiniMaxRegion: String, CaseIterable, Sendable {
    /// platform.minimax.cn
    case china
    /// platform.minimax.io
    case international

    public var endpoint: URL {
        switch self {
        case .china: URL(string: "https://api.minimax.cn/v1/chat/completions")!
        case .international: URL(string: "https://api.minimax.io/v1/chat/completions")!
        }
    }
}

public enum MiniMaxError: Error, Equatable, Sendable {
    case missingAPIKey
    case authenticationFailed
    case insufficientBalance
    case rateLimited
    case timedOut
    case offline
    case service(code: Int, message: String)
    case emptyReply
}

/// Calls MiniMax's OpenAI-compatible chat completions endpoint.
public struct MiniMaxClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    /// Answers directly when thinking is turned off, which keeps parsing quick.
    public static let defaultModel = "MiniMax-M3"

    public var apiKey: String
    public var region: MiniMaxRegion
    public var model: String
    private let transport: Transport

    public init(
        apiKey: String,
        region: MiniMaxRegion,
        model: String = MiniMaxClient.defaultModel,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.apiKey = apiKey
        self.region = region
        self.model = model
        self.transport = transport
    }

    /// Sends one system and one user message; returns the reply without any thinking.
    public func reply(system: String, user: String) async throws -> String {
        let request = try makeRequest(system: system, user: user)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw MiniMaxError.timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                throw MiniMaxError.offline
            default: throw MiniMaxError.service(code: error.errorCode, message: error.localizedDescription)
            }
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.replyText(from: data, status: status)
    }

    func makeRequest(system: String, user: String) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw MiniMaxError.missingAPIKey }

        var request = URLRequest(url: region.endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            model: model,
            messages: [.init(role: "system", content: system), .init(role: "user", content: user)],
            // Only MiniMax-M3 can switch thinking off; the others think regardless.
            thinking: model == "MiniMax-M3" ? .init(type: "disabled") : nil,
            reasoningSplit: true,
            maxCompletionTokens: 8192
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        return request
    }

    static func replyText(from data: Data, status: Int) throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard (200..<300).contains(status) else {
            // e.g. {"type":"error","error":{"type":"authorized_error","message":"login fail: … (1004)"}}
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data))?.error?.message ?? ""
            let code = Self.trailingCode(in: message) ?? status
            throw Self.error(code: status == 401 ? 1004 : status == 429 ? 1002 : code, message: message)
        }

        let response = try? decoder.decode(ResponseBody.self, from: data)
        if let base = response?.baseResp, base.statusCode != 0 {
            throw Self.error(code: base.statusCode, message: base.statusMsg ?? "")
        }
        let content = response?.choices?.first?.message?.content ?? ""
        let text = content
            .replacing(#/<think>[\s\S]*?</think>/#, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw MiniMaxError.emptyReply }
        return text
    }

    /// MiniMax's documented status codes.
    private static func error(code: Int, message: String) -> MiniMaxError {
        switch code {
        case 1001: .timedOut
        case 1002: .rateLimited
        case 1004: .authenticationFailed
        case 1008: .insufficientBalance
        default: .service(code: code, message: message)
        }
    }

    /// The "(1004)" at the end of some error messages.
    private static func trailingCode(in message: String) -> Int? {
        message.firstMatch(of: #/\((\d{4})\)\s*$/#).flatMap { Int($0.1) }
    }
}

private struct RequestBody: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct Thinking: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let thinking: Thinking?
    let reasoningSplit: Bool
    let maxCompletionTokens: Int
}

private struct ResponseBody: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message?
    }

    struct BaseResp: Decodable {
        let statusCode: Int
        let statusMsg: String?
    }

    let choices: [Choice]?
    let baseResp: BaseResp?
}

private struct ErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let message: String?
    }

    let error: Detail?
}
