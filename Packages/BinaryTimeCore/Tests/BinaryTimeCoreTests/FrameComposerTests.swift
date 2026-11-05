import Foundation
import XCTest
@testable import BinaryTimeCore

final class FrameComposerTests: XCTestCase {
    private func composer(_ settings: Settings = .default) -> FrameComposer {
        FrameComposer(resources: Fixtures.resources,
                      settings: settings,
                      timeZone: Fixtures.moscow,
                      preferredLanguages: ["en"],
                      osCalendar: .gregorian,
                      spaceRotator: SpaceRotator(count: Fixtures.catalog.objects.count, period: 20, epoch: Fixtures.referenceInstant, startIndex: 12),
                      now: Fixtures.referenceInstant)
    }

    func testSameSecondReturnsCachedModel() {
        let c = composer()
        let first = c.frame(at: Fixtures.date("2026-10-24T19:59:17.100+03:00"))
        let later = c.frame(at: Fixtures.date("2026-10-24T19:59:17.900+03:00"))
        c.invalidate()
        let rebuilt = c.frame(at: Fixtures.date("2026-10-24T19:59:17.900+03:00"))
        XCTAssertEqual(first, later)
        XCTAssertEqual(later, rebuilt)
        XCTAssertEqual(later.footer.readout, "2026·10·24  19:59:17")
    }

    func testSecondChangeRebuilds() {
        let c = composer()
        let a = c.frame(at: Fixtures.date("2026-10-24T19:59:17.990+03:00"))
        let b = c.frame(at: Fixtures.date("2026-10-24T19:59:18.000+03:00"))
        XCTAssertEqual(a.rows[5].decimal, "17")
        XCTAssertEqual(b.rows[5].decimal, "18")
    }

    func testSettingsResolveLanguageAndCalendar() {
        var s = Settings.default
        s.language = .fixed(.he)
        s.calendar = .hebrew
        let c = composer(s)
        let m = c.frame(at: Fixtures.referenceInstant)
        XCTAssertEqual(m.language, .he)
        XCTAssertEqual(m.columns, 13)
        XCTAssertEqual(c.calendar, .hebrew)
        XCTAssertEqual(m.location.l1, "Moscow · רוסיה")
    }

    func testSpaceModeRotatesEveryTwentySeconds() {
        var s = Settings.default
        s.location = .vpn
        let c = composer(s)
        let first = c.frame(at: Fixtures.referenceInstant)
        let sameWindow = c.frame(at: Fixtures.referenceInstant.addingTimeInterval(19))
        let nextWindow = c.frame(at: Fixtures.referenceInstant.addingTimeInterval(21))
        XCTAssertEqual(first.location.tag, "VPN · real location hidden")
        XCTAssertEqual(first.location.l1, Fixtures.catalog.objects[12].names["en"])
        XCTAssertEqual(sameWindow.location, first.location)
        XCTAssertEqual(nextWindow.location.l1, Fixtures.catalog.objects[13].names["en"])
    }

    func testDetectedVPNForcesSpaceMode() {
        let c = composer()
        XCTAssertFalse(c.isSpaceMode)
        c.vpnDetected = true
        XCTAssertTrue(c.isSpaceMode)
        XCTAssertEqual(c.frame(at: Fixtures.referenceInstant).location.tag, "VPN · real location hidden")
        c.vpnDetected = false
        XCTAssertEqual(c.frame(at: Fixtures.referenceInstant).location.l1, "Moscow · Russia")
    }

    func testCoordinatesSwitchTagToGeolocation() {
        let c = composer()
        c.coordinates = Coordinates(latitude: 55.7558, longitude: 37.6173)
        let m = c.frame(at: Fixtures.referenceInstant)
        XCTAssertEqual(m.location.tag, "Geolocation")
        XCTAssertEqual(m.location.l2, "55.76° N · 37.62° E")
    }
}
