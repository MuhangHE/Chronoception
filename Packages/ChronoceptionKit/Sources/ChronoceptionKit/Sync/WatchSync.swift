import Foundation

/// What the watch asks the phone to do. The phone keeps the log; the watch shows what
/// is running and sends these. Each carries the event's id, so a command delivered
/// twice changes nothing the second time.
public enum WatchCommand: Codable, Sendable, Equatable {
    case start(id: UUID, text: String, at: Date)
    case stop(id: UUID, at: Date)
}

/// What the phone tells the watch: the event running now, if any.
public struct WatchSnapshot: Codable, Sendable, Equatable {
    public struct Running: Codable, Sendable, Equatable {
        public var id: UUID
        public var title: String
        public var start: Date

        public init(id: UUID, title: String, start: Date) {
            self.id = id
            self.title = title
            self.start = start
        }
    }

    public var running: Running?
    /// When the phone made it. The watch ignores snapshots older than its own latest
    /// change, which the phone may not have seen yet.
    public var madeAt: Date

    public init(running: Running?, madeAt: Date) {
        self.running = running
        self.madeAt = madeAt
    }
}

/// Packs commands and snapshots into WatchConnectivity dictionaries and back.
public enum WatchMessage {
    static let commandKey = "command"
    static let snapshotKey = "snapshot"

    public static func payload(for command: WatchCommand) throws -> [String: Any] {
        [commandKey: try JSONEncoder().encode(command)]
    }

    public static func command(from payload: [String: Any]) -> WatchCommand? {
        (payload[commandKey] as? Data).flatMap { try? JSONDecoder().decode(WatchCommand.self, from: $0) }
    }

    public static func payload(for snapshot: WatchSnapshot) throws -> [String: Any] {
        [snapshotKey: try JSONEncoder().encode(snapshot)]
    }

    public static func snapshot(from payload: [String: Any]) -> WatchSnapshot? {
        (payload[snapshotKey] as? Data).flatMap { try? JSONDecoder().decode(WatchSnapshot.self, from: $0) }
    }
}
