import ChronoceptionKit
import SwiftUI

extension TimeLogError {
    var message: String {
        switch self {
        case .invalidInterval: "结束时间要晚于开始时间。"
        case .startsBeforeRunningEntry: "开始时间不能早于正在进行的活动。"
        case .splitPointOutsideEntry: "拆分时间要落在这条记录中间。"
        case .emptyTitle: "先写下要做的事。"
        }
    }
}

extension MiniMaxError {
    var message: String {
        switch self {
        case .missingAPIKey: "还没有填写 MiniMax API key，请到设置里填写。"
        case .authenticationFailed: "MiniMax 鉴权失败：检查 key 是否正确，以及平台选得对不对（国内和国际的 key 不通用）。"
        case .insufficientBalance: "MiniMax 账户余额不足。"
        case .rateLimited: "请求太频繁，稍后会自动重试。"
        case .timedOut: "MiniMax 响应超时，稍后会自动重试。"
        case .offline: "网络不可用，联网后会自动重试。"
        case .service(let code, let message): "MiniMax 出错（\(code)）\(message.isEmpty ? "" : "：\(message)")"
        case .emptyReply: "MiniMax 没有返回内容，可以重试。"
        }
    }
}

extension Error {
    /// Text to show in an alert.
    var userMessage: String {
        switch self {
        case let error as TimeLogError: error.message
        case let error as MiniMaxError: error.message
        case is TidyError: "没能读懂 MiniMax 的回复，稍后会再试。"
        case let error as KeychainError: "无法写入钥匙串（\(error.status)）。"
        default: localizedDescription
        }
    }
}

extension View {
    /// Shows `message` in an alert while it is non-nil.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "出错了",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
