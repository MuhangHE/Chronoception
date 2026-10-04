import ChronoceptionKit
import Foundation
import Network
import SwiftData

/// Tidies events' titles with MiniMax in the background, without asking the user
/// anything. Events still waiting (no key, no network, an error) are retried on
/// launch, when the network comes back, and when the app returns to the foreground.
final class TitleTidier {
    private var context: ModelContext?
    private let monitor = NWPathMonitor()
    /// Notes being tidied right now, so overlapping retries skip them.
    private var inFlight: Set<UUID> = []

    func start(with context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        // Called once right away, then on every change: also covers launch.
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.tidyWaiting() }
        }
        monitor.start(queue: .main)
    }

    /// Tidies one event's title; a failure is kept on its note for a later retry.
    func tidy(noteID: UUID) async {
        guard let context, !inFlight.contains(noteID) else { return }
        let log = TimeLog(context: context)
        guard let note = try? log.voiceNote(id: noteID), note.status != .parsed else { return }

        inFlight.insert(noteID)
        defer { inFlight.remove(noteID) }
        do {
            let result = try await EventTidier(client: ParserSettings.client()).tidy(log.tidyContext(for: note))
            // The event may have been deleted while waiting for MiniMax.
            if let note = try log.voiceNote(id: noteID) {
                try log.apply(result, to: note)
            }
        } catch {
            if let note = try? log.voiceNote(id: noteID) {
                try? log.recordFailure(note, message: error.userMessage)
            }
        }
    }

    /// Tidies, one at a time, every event still waiting.
    func tidyWaiting() async {
        guard let context else { return }
        let waiting = (try? TimeLog(context: context).notesWaitingForTidy()) ?? []
        for id in waiting.map(\.id) {
            await tidy(noteID: id)
        }
    }
}
