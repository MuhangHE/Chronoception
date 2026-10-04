import ChronoceptionKit
import SwiftData
import SwiftUI

@main
struct ChronoceptionApp: App {
    let container: ModelContainer
    let watchLink: WatchLink

    init() {
        #if DEBUG
        let demo = DemoData.isRequested
        #else
        let demo = false
        #endif
        do {
            container = try ChronoceptionStore.makeContainer(inMemory: demo)
        } catch {
            fatalError("Could not open the time log store: \(error)")
        }
        #if DEBUG
        if demo { DemoData.fill(TimeLog(context: container.mainContext)) }
        #endif
        do {
            // Entries from before categories were dropped keep their category's name as title.
            try TimeLog(context: container.mainContext).adoptCategoryNamesAsTitles()
        } catch {
            print("Giving older entries titles failed: \(error)")
        }
        watchLink = WatchLink(container: container)
    }

    var body: some Scene {
        WindowGroup {
            DayScreen(watchLink: watchLink)
                .tint(Theme.accent)
                .environment(\.locale, .chinese24Hour)
        }
        .modelContainer(container)
    }
}
