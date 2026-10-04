import Foundation

/// What the widgets show: the event running now, if any. Widgets run in their own
/// process, so the app keeps it in the defaults of an app group it shares with them;
/// the Info.plist names the group under `ChronoceptionAppGroup`.
public enum Glance {
    static let runningKey = "running"

    /// The app group's defaults, or nil when the Info.plist names no group.
    public static var sharedDefaults: UserDefaults? {
        (Bundle.main.object(forInfoDictionaryKey: "ChronoceptionAppGroup") as? String)
            .flatMap(UserDefaults.init(suiteName:))
    }

    public static func running(in defaults: UserDefaults? = sharedDefaults) -> WatchSnapshot.Running? {
        defaults?.data(forKey: runningKey).flatMap { try? JSONDecoder().decode(WatchSnapshot.Running.self, from: $0) }
    }

    /// Keeps `running` for the widgets. Returns whether it changed, which is when they
    /// need reloading.
    @discardableResult
    public static func save(_ running: WatchSnapshot.Running?, in defaults: UserDefaults? = sharedDefaults) -> Bool {
        guard let defaults, running != Self.running(in: defaults) else { return false }
        defaults.set(running.flatMap { try? JSONEncoder().encode($0) }, forKey: runningKey)
        return true
    }
}

/// The link a widget opens the app with.
public enum AppLink {
    /// Start something: the phone opens its start bar, and the watch, unless something
    /// is running, goes straight to dictation.
    public static let start = URL(string: "chronoception://start")!
}
