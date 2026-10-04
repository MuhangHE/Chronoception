import SwiftUI

/// Where an event starts: write what you are about to do, tap start, and it is running.
struct StartBar: View {
    /// Whether something is running now, which starting will end.
    let isRunning: Bool
    /// Whether the field has the keyboard. The day screen gives it the keyboard when a
    /// widget opens the app.
    var focused: FocusState<Bool>.Binding
    let onStart: (String) -> Void

    @State private var text = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            TextField(isRunning ? "接下来做什么？" : "现在要做什么？", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .focused(focused)
                .submitLabel(.go)
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 11)
                .padding(.leading, 14)
                .onChange(of: text) { _, newText in
                    // Return starts the event instead of beginning a new line.
                    if newText.hasSuffix("\n") {
                        text = String(newText.dropLast())
                        start()
                    }
                }
            Button(action: start) {
                Image(systemName: "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accent.opacity(canStart ? 1 : 0.35), in: .circle)
            }
            .disabled(!canStart)
            .padding(6)
            .accessibilityLabel("开始")
        }
        .background(Theme.surface, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(focused.wrappedValue ? Theme.accent.opacity(0.5) : Theme.hairline)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 0.5)
        }
    }

    private var canStart: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func start() {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        onStart(title)
        text = ""
        focused.wrappedValue = false
    }
}
