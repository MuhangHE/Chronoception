import SwiftUI

@main
struct ChronoceptionWatchApp: App {
    @State private var session = WatchSession()

    var body: some Scene {
        WindowGroup {
            WatchHome()
                .environment(session)
        }
        // Woken to receive what the phone sent, so the complication catches up.
        .backgroundTask(.watchConnectivity) { [session] in
            await session.receivePending()
        }
    }
}
