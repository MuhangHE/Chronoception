import ChronoceptionKit
import SwiftUI
import WatchKit

/// Open, say what you are about to do, and it starts; later, end it.
struct WatchHome: View {
    @Environment(WatchSession.self) private var session

    /// Claude's clay, as on the phone.
    private let clay = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)

    var body: some View {
        content
            // The complication was tapped: with nothing running, straight to dictation.
            .onOpenURL { url in
                guard url == AppLink.start else { return }
                Task {
                    // Catch up with the phone first; the complication may have been behind.
                    await session.receivePending()
                    if session.running == nil { await dictate() }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let running = session.running {
            VStack(spacing: 10) {
                Text(running.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Text(timerInterval: running.start...Date.distantFuture, countsDown: false)
                    .font(.system(.title2, design: .serif).monospacedDigit())
                    .foregroundStyle(clay)
                Button("结束") { session.stop() }
                    .buttonStyle(.borderedProminent)
                    .tint(clay)
            }
            .padding(.horizontal)
        } else {
            VStack(spacing: 12) {
                TextFieldLink(prompt: Text("现在要做什么？")) {
                    Image(systemName: "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(clay, in: .circle)
                } onSubmit: { text in
                    session.start(text)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("说一件事，开始计时")
                Text("说一件事，开始计时")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The system's text input, straight into dictation: no suggestions, plain text.
    private func dictate() async {
        let app = WKApplication.shared()
        guard let controller = app.visibleInterfaceController ?? app.rootInterfaceController else { return }
        let results = await controller.presentTextInputController(withSuggestions: nil, allowedInputMode: .plain)
        if let text = results?.first as? String {
            session.start(text)
        }
    }
}
