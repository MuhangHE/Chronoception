import ChronoceptionKit
import Foundation

/// A sheet the day screen presents. Every request gets a fresh id, so presenting it
/// never reads a model that may have been deleted in the meantime.
struct EntrySheet: Identifiable {
    enum Kind {
        case new(DateInterval)
        case edit(TimeEntry)
        case split(TimeEntry)
        case settings
    }

    let id = UUID()
    let kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }
}
