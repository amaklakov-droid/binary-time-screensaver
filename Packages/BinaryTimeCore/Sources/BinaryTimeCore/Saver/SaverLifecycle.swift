import Foundation

/// Lifecycle rules for the legacy screen-saver host (MACOS.md §2). AppKit-free so they can be tested;
/// the `.saver` view only feeds in what the framework reports.
public enum SaverLifecycle {
    /// Distributed notification posted when the screen saver is dismissed (MACOS.md §2.1).
    public static let willStopNotification = "com.apple.screensaver.willstop"

    /// The app that shows the full-screen saver. If it dies without `willstop`, the host process
    /// stays alive with our views still drawing off screen; its termination counts as `willstop`.
    public static let engineBundleIdentifier = "com.apple.ScreenSaver.Engine"

    /// Views narrower or shorter than this are previews, whatever `isPreview` says (MACOS.md §2.4).
    public static let previewMaxSide: Double = 400

    /// `isPreview` can be wrong on Tahoe, so a small view is a preview too.
    public static func isPreview(reported: Bool, width: Double, height: Double) -> Bool {
        reported || (width > 0 && height > 0 && min(width, height) < previewMaxSide)
    }

    /// On `willstop` a full-screen instance quits the host process with `exit(0)`, because the host never
    /// tears old instances down (MACOS.md §2.1). Previews stay: System Settings keeps showing them.
    public static func exitsOnWillStop(isPreview: Bool) -> Bool {
        !isPreview
    }
}

/// Notices the screen-saver engine dying without `willstop` (a crash, `killall`): the host then keeps
/// our view drawing for nobody. Workspace notifications don't reach the host, so the view polls.
/// Only a disappearance counts: previews in System Settings run without the engine at all.
/// A single empty answer is not enough: the running-app list can come back empty for a moment while
/// LaunchServices updates it, and one such miss once quit a saver whose engine kept running (MACOS.md §2.9).
public struct EngineWatch: Sendable {
    public static let pollInterval: TimeInterval = 2
    /// Consecutive polls without the engine before it counts as gone.
    public static let missesToStop = 3

    private var sawEngine = false
    private var misses = 0

    public init() {}

    /// Feeds one poll; returns true once the engine has been missing for `missesToStop` polls in a row
    /// after being seen.
    public mutating func update(engineRunning: Bool) -> Bool {
        if engineRunning {
            sawEngine = true
            misses = 0
            return false
        }
        guard sawEngine else { return false }
        misses += 1
        return misses >= Self.missesToStop
    }
}

/// Why a full-screen instance quits the host, for the system log.
public enum SaverExitReason: String, Sendable {
    /// `com.apple.screensaver.willstop` arrived.
    case willStop = "willstop"
    /// The engine disappeared without `willstop` (`EngineWatch`).
    case engineGone = "engine gone"
}

/// Where a saver instance draws: one screen, full screen or preview.
public struct SaverSlot: Hashable, Sendable {
    public var screen: String
    public var isPreview: Bool

    public init(screen: String, isPreview: Bool) {
        self.screen = screen
        self.isPreview = isPreview
    }
}

/// At most one live instance per slot (MACOS.md §2.1, §2.5). The host creates a new view on every
/// activation while old ones keep running; the newest one wins and the caller stops the one returned.
public struct SaverInstanceRegistry<ID: Hashable> {
    private var live: [SaverSlot: ID] = [:]

    public init() {}

    /// Registers `id` as the live instance of `slot`; returns the instance it replaces, if any.
    public mutating func activate(_ id: ID, in slot: SaverSlot) -> ID? {
        // An instance that moved to another slot (screen change) leaves its old one.
        if let old = live.first(where: { $0.value == id && $0.key != slot })?.key { live[old] = nil }
        let previous = live[slot]
        live[slot] = id
        return previous == id ? nil : previous
    }

    public mutating func deactivate(_ id: ID) {
        for (slot, value) in live where value == id { live[slot] = nil }
    }

    public func isLive(_ id: ID) -> Bool {
        live.values.contains(id)
    }

    public var liveCount: Int { live.count }
}
