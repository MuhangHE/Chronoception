import ChronoceptionKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Chronoception")
                .font(.headline)
            Text("Kit \(Chrono.kitVersion)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
