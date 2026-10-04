import Foundation
import Testing
@testable import ChronoceptionKit

/// One after another: they share a defaults domain, so they leave a single (empty)
/// file in ~/Library/Preferences rather than one per run.
@Suite(.serialized)
struct GlanceTests {
    let reading = WatchSnapshot.Running(id: UUID(), title: "读文献", start: TestDates.date(4, 9))

    /// Runs `body` with empty defaults, emptied again afterwards.
    func withDefaults(_ body: (UserDefaults) -> Void) throws {
        let suite = "ChronoceptionKitTests.Glance"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func keepsWhatIsRunning() throws {
        try withDefaults { defaults in
            #expect(Glance.running(in: defaults) == nil)
            Glance.save(reading, in: defaults)
            #expect(Glance.running(in: defaults) == reading)
            Glance.save(nil, in: defaults)
            #expect(Glance.running(in: defaults) == nil)
        }
    }

    @Test func savingReportsOnlyChanges() throws {
        try withDefaults { defaults in
            #expect(!Glance.save(nil, in: defaults))
            #expect(Glance.save(reading, in: defaults))
            #expect(!Glance.save(reading, in: defaults))

            var tidied = reading
            tidied.title = "读文献：注意力机制综述"
            #expect(Glance.save(tidied, in: defaults))
            #expect(Glance.save(nil, in: defaults))
            #expect(!Glance.save(nil, in: defaults))
        }
    }

    @Test func withoutAnAppGroupNothingIsKept() {
        #expect(!Glance.save(reading, in: nil))
        #expect(Glance.running(in: nil) == nil)
    }
}
