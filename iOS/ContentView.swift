import ChronoceptionKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 56))
            Text("Chronoception")
                .font(.largeTitle.bold())
            Text("iPhone · ChronoceptionKit \(Chrono.kitVersion)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
