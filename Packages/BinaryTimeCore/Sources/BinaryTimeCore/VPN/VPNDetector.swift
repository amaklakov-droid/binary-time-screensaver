import Foundation
import SystemConfiguration

/// Source of the primary network interface name (`en0`, `utun4`, …).
public protocol PrimaryInterfaceProviding {
    func primaryInterfaceName() -> String?
}

/// Layer 1 of SPEC §4.4: the *primary* interface is a tunnel ⇒ VPN. No network calls.
/// macOS always has idle `utun0–3` (iCloud, Continuity), so only the primary interface counts.
public enum VPNHeuristics {
    public static let tunnelPrefixes = ["utun", "ipsec", "ppp"]

    public static func isVPNInterface(_ name: String?) -> Bool {
        guard let name, !name.isEmpty else { return false }
        return tunnelPrefixes.contains { name.hasPrefix($0) }
    }
}

public struct LocalVPNDetector {
    public let provider: PrimaryInterfaceProviding

    public init(provider: PrimaryInterfaceProviding) {
        self.provider = provider
    }

    public func isVPNActive() -> Bool {
        VPNHeuristics.isVPNInterface(provider.primaryInterfaceName())
    }
}

/// Reads `State:/Network/Global/IPv4 › PrimaryInterface` from the dynamic store.
public final class SystemPrimaryInterfaceProvider: PrimaryInterfaceProviding {
    public static let globalIPv4Key = "State:/Network/Global/IPv4"

    public init() {}

    public func primaryInterfaceName() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "BinaryTime" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, SystemPrimaryInterfaceProvider.globalIPv4Key as CFString) as? [String: Any]
        else { return nil }
        return value["PrimaryInterface"] as? String
    }
}

/// Calls `onChange` on the given run loop whenever the primary interface changes.
public final class VPNChangeMonitor {
    private var store: SCDynamicStore?
    private var source: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private let handler: () -> Void

    public init(onChange: @escaping () -> Void) {
        handler = onChange
    }

    deinit { stop() }

    @discardableResult
    public func start(on runLoop: CFRunLoop = CFRunLoopGetMain()) -> Bool {
        stop()
        var context = SCDynamicStoreContext(version: 0,
                                            info: Unmanaged.passUnretained(self).toOpaque(),
                                            retain: nil, release: nil, copyDescription: nil)
        let callback: SCDynamicStoreCallBack = { _, _, info in
            guard let info else { return }
            Unmanaged<VPNChangeMonitor>.fromOpaque(info).takeUnretainedValue().handler()
        }
        guard let store = SCDynamicStoreCreate(nil, "BinaryTime.VPNMonitor" as CFString, callback, &context) else { return false }
        let keys = [SystemPrimaryInterfaceProvider.globalIPv4Key as CFString] as CFArray
        guard SCDynamicStoreSetNotificationKeys(store, keys, nil),
              let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
        else { return false }
        CFRunLoopAddSource(runLoop, source, .commonModes)
        self.store = store
        self.source = source
        self.runLoop = runLoop
        return true
    }

    public func stop() {
        if let source, let runLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        source = nil
        store = nil
        runLoop = nil
    }
}
