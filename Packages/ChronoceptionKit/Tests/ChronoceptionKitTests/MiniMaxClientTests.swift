import Foundation
import Testing
@testable import ChronoceptionKit

/// A stand-in for the network that answers every request with a canned response.
private func fakeTransport(status: Int, body: String) -> MiniMaxClient.Transport {
    { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

private func failingTransport(_ code: URLError.Code) -> MiniMaxClient.Transport {
    { _ in throw URLError(code) }
}

private func reply(content: String, statusCode: Int = 0, message: String = "") -> String {
    let encoded = String(data: try! JSONEncoder().encode(content), encoding: .utf8)!
    return """
    {"choices": [{"index": 0, "message": {"role": "assistant", "content": \(encoded)}}],
     "base_resp": {"status_code": \(statusCode), "status_msg": "\(message)"}}
    """
}

struct MiniMaxClientTests {
    @Test func buildsTheRequestForEachRegion() throws {
        let client = MiniMaxClient(apiKey: " sk-test \n", region: .china)
        let request = try client.makeRequest(system: "规则", user: "九点到十点上课")

        #expect(request.url?.absoluteString == "https://api.minimax.cn/v1/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(body["model"] as? String == "MiniMax-M3")
        #expect((body["thinking"] as? [String: String])?["type"] == "disabled")
        #expect(body["reasoning_split"] as? Bool == true)
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages == [["role": "system", "content": "规则"], ["role": "user", "content": "九点到十点上课"]])

        let international = MiniMaxClient(apiKey: "k", region: .international, model: "MiniMax-M2.7-highspeed")
        let other = try international.makeRequest(system: "", user: "")
        #expect(other.url?.host == "api.minimax.io")
        let otherBody = try #require(JSONSerialization.jsonObject(with: other.httpBody ?? Data()) as? [String: Any])
        #expect(otherBody["thinking"] == nil)
    }

    @Test func refusesToSendWithoutAKey() async {
        let client = MiniMaxClient(apiKey: "  ", region: .china, transport: { _ in
            Issue.record("No request should be sent without a key")
            throw URLError(.badURL)
        })
        await #expect(throws: MiniMaxError.missingAPIKey) {
            try await client.reply(system: "", user: "")
        }
    }

    @Test func returnsTheReplyWithoutThinking() async throws {
        let client = MiniMaxClient(apiKey: "k", region: .china, transport: fakeTransport(
            status: 200,
            body: reply(content: "<think>先想想</think>\n{\"actions\": []}")
        ))
        #expect(try await client.reply(system: "", user: "") == #"{"actions": []}"#)
    }

    @Test func mapsServiceStatusCodes() async {
        let cases: [(Int, MiniMaxError)] = [
            (1004, .authenticationFailed),
            (1008, .insufficientBalance),
            (1002, .rateLimited),
            (1001, .timedOut),
            (2013, .service(code: 2013, message: "invalid params")),
        ]
        for (code, expected) in cases {
            let client = MiniMaxClient(apiKey: "k", region: .china, transport: fakeTransport(
                status: 200,
                body: reply(content: "", statusCode: code, message: "invalid params")
            ))
            await #expect(throws: expected) { try await client.reply(system: "", user: "") }
        }
    }

    @Test func mapsHTTPErrors() async {
        let unauthorized = MiniMaxClient(apiKey: "k", region: .international, transport: fakeTransport(
            status: 401,
            body: #"{"type":"error","error":{"type":"authorized_error","message":"login fail: Please carry the API secret key in the 'Authorization' field of the request header (1004)","http_code":"401"}}"#
        ))
        await #expect(throws: MiniMaxError.authenticationFailed) { try await unauthorized.reply(system: "", user: "") }

        let broken = MiniMaxClient(apiKey: "k", region: .china, transport: fakeTransport(status: 502, body: "Bad Gateway"))
        await #expect(throws: MiniMaxError.service(code: 502, message: "")) { try await broken.reply(system: "", user: "") }
    }

    @Test func mapsNetworkFailures() async {
        let offline = MiniMaxClient(apiKey: "k", region: .china, transport: failingTransport(.notConnectedToInternet))
        await #expect(throws: MiniMaxError.offline) { try await offline.reply(system: "", user: "") }

        let slow = MiniMaxClient(apiKey: "k", region: .china, transport: failingTransport(.timedOut))
        await #expect(throws: MiniMaxError.timedOut) { try await slow.reply(system: "", user: "") }
    }

    @Test func anEmptyReplyIsAnError() async {
        let client = MiniMaxClient(apiKey: "k", region: .china, transport: fakeTransport(
            status: 200, body: reply(content: "<think>…</think>")
        ))
        await #expect(throws: MiniMaxError.emptyReply) { try await client.reply(system: "", user: "") }
    }

    @Test func theTidierSendsThePromptAndReadsTheResult() async throws {
        let context = TidyContext(
            text: "嗯现在开始写论文第三章",
            startedAt: TestDates.date(4, 14),
            timeZone: TestDates.calendar.timeZone
        )
        let client = MiniMaxClient(apiKey: "k", region: .china, transport: { request in
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let messages = body["messages"] as! [[String: String]]
            #expect(messages[0]["content"] == TidyPrompt.system(for: context))
            #expect(messages[1]["content"] == "嗯现在开始写论文第三章")
            let content = #"{"title": "写论文第三章", "start": null}"#
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(reply(content: content).utf8), response)
        })

        let result = try await EventTidier(client: client).tidy(context)
        #expect(result == TidyResult(title: "写论文第三章"))
    }
}
