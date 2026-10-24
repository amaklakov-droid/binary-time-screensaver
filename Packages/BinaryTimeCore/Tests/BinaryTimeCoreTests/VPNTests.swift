import Foundation
import XCTest
@testable import BinaryTimeCore

final class VPNTests: XCTestCase {
    struct FakeProvider: PrimaryInterfaceProviding {
        var name: String?
        func primaryInterfaceName() -> String? { name }
    }

    func testTunnelPrefixes() {
        XCTAssertTrue(VPNHeuristics.isVPNInterface("utun4"))
        XCTAssertTrue(VPNHeuristics.isVPNInterface("utun0"))
        XCTAssertTrue(VPNHeuristics.isVPNInterface("ipsec0"))
        XCTAssertTrue(VPNHeuristics.isVPNInterface("ppp0"))
        XCTAssertFalse(VPNHeuristics.isVPNInterface("en0"))
        XCTAssertFalse(VPNHeuristics.isVPNInterface("en5"))
        XCTAssertFalse(VPNHeuristics.isVPNInterface("bridge100"))
        XCTAssertFalse(VPNHeuristics.isVPNInterface("awdl0"))
        XCTAssertFalse(VPNHeuristics.isVPNInterface(""))
        XCTAssertFalse(VPNHeuristics.isVPNInterface(nil))
    }

    func testDetectorUsesOnlyThePrimaryInterface() {
        XCTAssertTrue(LocalVPNDetector(provider: FakeProvider(name: "utun3")).isVPNActive())
        XCTAssertFalse(LocalVPNDetector(provider: FakeProvider(name: "en0")).isVPNActive())
        XCTAssertFalse(LocalVPNDetector(provider: FakeProvider(name: nil)).isVPNActive(), "No network → not a VPN")
    }

    func testSystemProviderReturnsPlausibleName() {
        // Depends on the machine: either offline (nil) or an interface name.
        let name = SystemPrimaryInterfaceProvider().primaryInterfaceName()
        if let name {
            XCTAssertFalse(name.isEmpty)
            XCTAssertFalse(name.contains(" "))
        }
    }

    func testMonitorStartsAndStops() {
        let monitor = VPNChangeMonitor(onChange: {})
        XCTAssertTrue(monitor.start(on: CFRunLoopGetCurrent()))
        monitor.stop()
        monitor.stop()
    }
}
