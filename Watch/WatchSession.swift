import ChronoceptionKit
import Foundation
import Observation
import WatchConnectivity

/// The watch's side: shows what is running, and sends starts and stops to the phone,
/// which keeps the log. Works with the phone out of reach; the system delivers the
/// commands, in order, once it is back.
@Observable
final class WatchSession: NSObject, WCSessionDelegate {
    private(set) var running: WatchSnapshot.Running?

    /// When the watch last started or stopped something. Snapshots the phone made
    /// before then don't know about it yet, so they are ignored.
    @ObservationIgnored private var lastChange: Date

    private static let runningKey = "running"
    private static let lastChangeKey = "lastChange"

    override init() {
        let defaults = UserDefaults.standard
        running = (defaults.data(forKey: Self.runningKey))
            .flatMap { try? JSONDecoder().decode(WatchSnapshot.Running.self, from: $0) }
        lastChange = defaults.object(forKey: Self.lastChangeKey) as? Date ?? .distantPast
        super.init()
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func start(_ text: String) {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let now = Date.now
        let event = WatchSnapshot.Running(id: UUID(), title: title, start: now)
        running = event
        changed(at: now)
        send(.start(id: event.id, text: title, at: now))
    }

    func stop() {
        guard let event = running else { return }
        let now = Date.now
        running = nil
        changed(at: now)
        send(.stop(id: event.id, at: now))
    }

    private func changed(at time: Date) {
        lastChange = time
        save()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(running.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.runningKey)
        defaults.set(lastChange, forKey: Self.lastChangeKey)
    }

    /// Straight to the phone when it is reachable and nothing is queued ahead; otherwise
    /// queued, so commands always arrive in order.
    private func send(_ command: WatchCommand) {
        guard let payload = try? WatchMessage.payload(for: command) else { return }
        let session = WCSession.default
        if session.activationState == .activated, session.isReachable, session.outstandingUserInfoTransfers.isEmpty {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func receive(_ snapshot: WatchSnapshot) {
        guard snapshot.madeAt >= lastChange else { return }
        running = snapshot.running
        save()
    }

    // MARK: - WCSessionDelegate, called off the main thread

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard let snapshot = WatchMessage.snapshot(from: session.receivedApplicationContext) else { return }
        Task { @MainActor in self.receive(snapshot) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        guard let snapshot = WatchMessage.snapshot(from: context) else { return }
        Task { @MainActor in self.receive(snapshot) }
    }
}
