import ChronoceptionKit
import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// The watch's side: shows what is running, and sends starts and stops to the phone,
/// which keeps the log. Works with the phone out of reach; the system delivers the
/// commands, in order, once it is back.
@Observable
final class WatchSession: NSObject, WCSessionDelegate {
    private(set) var running: WatchSnapshot.Running?

    /// When what the watch shows last changed: it started or stopped something, or took
    /// a snapshot from the phone. Snapshots made before then are out of date (the phone
    /// hadn't heard yet, or a newer one came first), so they are ignored.
    @ObservationIgnored private var lastChange: Date

    private static let runningKey = "running"
    private static let lastChangeKey = "lastChange"

    override init() {
        let defaults = UserDefaults.standard
        running = (defaults.data(forKey: Self.runningKey))
            .flatMap { try? JSONDecoder().decode(WatchSnapshot.Running.self, from: $0) }
        lastChange = defaults.object(forKey: Self.lastChangeKey) as? Date ?? .distantPast
        super.init()
        updateComplication()
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
        updateComplication()
    }

    /// Keeps the complication showing what is running.
    private func updateComplication() {
        if Glance.save(running) { WidgetCenter.shared.reloadAllTimelines() }
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
        changed(at: snapshot.madeAt)
    }

    /// Waits until what the phone sent has arrived (at most about ten seconds); the
    /// delegate below receives it. For when the system wakes the app in the background to
    /// deliver it, since the app may be suspended once this returns.
    func receivePending() async {
        let session = WCSession.default
        for _ in 0..<100 {
            if session.activationState == .activated, !session.hasContentPending { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        // Let the snapshots just delivered be applied.
        try? await Task.sleep(for: .milliseconds(100))
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

    /// The same snapshots, sent this way too so they arrive at once, waking the app in
    /// the background to update the complication.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let snapshot = WatchMessage.snapshot(from: userInfo) else { return }
        Task { @MainActor in self.receive(snapshot) }
    }
}
