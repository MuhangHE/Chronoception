import ChronoceptionKit
import Foundation
import SwiftData
import WatchConnectivity
import WidgetKit

/// The phone's side of the watch connection: applies the watch's starts and stops to
/// the log, which lives here, and keeps the watch, and the widgets, told what is
/// running. Set up at launch, since a message from the watch can wake the app in the
/// background.
final class WatchLink: NSObject, WCSessionDelegate {
    private let container: ModelContainer
    /// Called with the voice note of an event the watch started, to tidy its title.
    var onWatchEvent: ((UUID) -> Void)?

    init(container: ModelContainer) {
        self.container = container
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Tells the widgets and the watch what is running. A newer call replaces one not
    /// yet delivered.
    func publish() {
        let snapshot: WatchSnapshot
        do {
            snapshot = try TimeLog(context: container.mainContext).watchSnapshot()
        } catch {
            print("Reading what is running failed: \(error)")
            return
        }
        let changed = Glance.save(snapshot.running)
        if changed { WidgetCenter.shared.reloadAllTimelines() }

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        do {
            let payload = try WatchMessage.payload(for: snapshot)
            try session.updateApplicationContext(payload)
            // Sent this way too, it arrives at once and wakes the watch app in the background
            // to update its complication; the system allows 50 a day. (Not gated on
            // isComplicationEnabled, which can read false with the complication on the face.)
            if changed, session.remainingComplicationUserInfoTransfers > 0 {
                session.transferCurrentComplicationUserInfo(payload)
            }
        } catch {
            print("Telling the watch what is running failed: \(error)")
        }
    }

    private func handle(_ command: WatchCommand) {
        do {
            let note = try TimeLog(context: container.mainContext).apply(command)
            publish()
            if let note { onWatchEvent?(note.id) }
        } catch {
            print("Applying a command from the watch failed: \(error)")
        }
    }

    // MARK: - WCSessionDelegate, called off the main thread

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.publish() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switched to another watch: talk to that one.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        // E.g. the watch app was just installed.
        Task { @MainActor in self.publish() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let command = WatchMessage.command(from: message) else { return }
        Task { @MainActor in self.handle(command) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let command = WatchMessage.command(from: userInfo) else { return }
        Task { @MainActor in self.handle(command) }
    }
}
