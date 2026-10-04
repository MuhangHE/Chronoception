import SwiftUI

@main
struct ChronoceptionWatchApp: App {
    @State private var session = WatchSession()

    var body: some Scene {
        WindowGroup {
            WatchHome()
                .environment(session)
        }
    }
}
