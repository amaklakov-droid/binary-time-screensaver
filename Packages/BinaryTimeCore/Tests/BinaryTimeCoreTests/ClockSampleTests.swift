import Foundation
import XCTest
@testable import BinaryTimeCore

final class ClockSampleTests: XCTestCase {
    func testReferenceMoment() {
        let s = Fixtures.sample("2026-10-24T19:59:17.800+03:00")
        XCTAssertEqual([s.hour24, s.minute, s.second], [19, 59, 17])
        XCTAssertEqual(s.date.year, 2026)
        XCTAssertTrue(s.isPM)
    }

    func testSecondsNeverRoundUpEarly() {
        for cs in 0..<100 {
            let iso = String(format: "2026-10-24T19:59:17.%02d0+03:00", cs)
            XCTAssertEqual(Fixtures.sample(iso).second, 17, iso)
        }
        XCTAssertEqual(Fixtures.sample("2026-10-24T19:59:18.000+03:00").second, 18)
    }

    func testTwelveHourDisplay() {
        XCTAssertEqual(Fixtures.sample("2026-10-24T00:05:00+03:00").displayHour(.h12), 12)
        XCTAssertEqual(Fixtures.sample("2026-10-24T12:05:00+03:00").displayHour(.h12), 12)
        XCTAssertEqual(Fixtures.sample("2026-10-24T13:05:00+03:00").displayHour(.h12), 1)
        XCTAssertEqual(Fixtures.sample("2026-10-24T19:05:00+03:00").displayHour(.h12), 7)
        XCTAssertEqual(Fixtures.sample("2026-10-24T19:05:00+03:00").displayHour(.h24), 19)
        XCTAssertFalse(Fixtures.sample("2026-10-24T00:05:00+03:00").isPM)
        XCTAssertTrue(Fixtures.sample("2026-10-24T12:00:00+03:00").isPM)
    }

    func testMetricWidths() {
        let s = Fixtures.sample("2026-10-24T12:00:00+03:00")
        XCTAssertEqual(s.value(of: .year, hourFormat: .h24).bits, 11)
        XCTAssertEqual(s.value(of: .month, hourFormat: .h24).bits, 4)
        XCTAssertEqual(s.value(of: .day, hourFormat: .h24).bits, 5)
        XCTAssertEqual(s.value(of: .hours, hourFormat: .h24).bits, 5)
        XCTAssertEqual(s.value(of: .hours, hourFormat: .h12).bits, 4)
        XCTAssertEqual(s.value(of: .hours, hourFormat: .h12).value, 12)
        XCTAssertEqual(s.value(of: .minutes, hourFormat: .h24).bits, 6)
        XCTAssertEqual(s.value(of: .seconds, hourFormat: .h24).bits, 6)
        let hebrew = Fixtures.sample("2026-10-24T12:00:00+03:00", calendar: .hebrew)
        XCTAssertEqual(hebrew.value(of: .year, hourFormat: .h24).bits, 13)
    }

    func testYearChangeKeepsColumnsUntil2048() {
        let before = Fixtures.sample("2026-12-31T23:59:59.990+03:00")
        let after = Fixtures.sample("2027-01-01T00:00:00.000+03:00")
        XCTAssertEqual([before.date.year, before.hour24, before.minute, before.second], [2026, 23, 59, 59])
        XCTAssertEqual([after.date.year, after.date.month, after.date.day, after.hour24, after.second], [2027, 1, 1, 0, 0])
        XCTAssertEqual(BinaryModel.columns(forYear: before.date.year), BinaryModel.columns(forYear: after.date.year))
        XCTAssertEqual(BinaryModel.columns(forYear: Fixtures.sample("2047-12-31T23:00:00+03:00").date.year), 11)
        XCTAssertEqual(BinaryModel.columns(forYear: Fixtures.sample("2048-01-01T01:00:00+03:00").date.year), 12)
    }

    func testTimeZoneAffectsHoursNotSeconds() {
        let tokyo = Fixtures.sample("2026-10-24T19:59:17.800+03:00", zone: TimeZone(identifier: "Asia/Tokyo")!)
        XCTAssertEqual([tokyo.hour24, tokyo.minute, tokyo.second], [1, 59, 17])
        XCTAssertEqual(tokyo.date.day, 25)
        let kolkata = Fixtures.sample("2026-10-24T19:59:17.800+03:00", zone: TimeZone(identifier: "Asia/Kolkata")!)
        XCTAssertEqual([kolkata.hour24, kolkata.minute], [22, 29])
    }
}
