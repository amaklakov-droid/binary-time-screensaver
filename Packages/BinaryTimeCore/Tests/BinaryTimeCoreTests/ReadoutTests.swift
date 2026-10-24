import Foundation
import XCTest
@testable import BinaryTimeCore

final class ReadoutTests: XCTestCase {
    let i18n = Fixtures.i18n
    let lrm = Readout.lrm

    func testLatinReadout() {
        let s = Fixtures.sample("2026-10-24T19:59:17.800+03:00")
        XCTAssertEqual(Readout.text(sample: s, hourFormat: .h24, lang: .en, catalog: i18n), "2026·10·24  19:59:17.80")
        XCTAssertEqual(Readout.text(sample: s, hourFormat: .h12, lang: .ru, catalog: i18n), "2026·10·24  07:59:17.80")
    }

    func testArabicReadoutUsesSlashAndLRM() {
        let s = Fixtures.sample("2026-10-24T19:59:24.420+03:00", calendar: .islamic)
        let text = Readout.text(sample: s, hourFormat: .h12, lang: .ar, catalog: i18n)
        XCTAssertEqual(text, "١٤٤٨\(lrm)/\(lrm)٠٥\(lrm)/\(lrm)١٣\(lrm)  \(lrm)٠٧:٥٩:٢٤.٤٢")
        XCTAssertFalse(text.contains("·"))
    }

    func testTibetanReadoutKeepsDotWithLRM() {
        let s = Fixtures.sample("2026-10-24T19:59:17.800+03:00", calendar: .buddhist)
        let text = Readout.text(sample: s, hourFormat: .h24, lang: .bo, catalog: i18n)
        XCTAssertEqual(text, "༢༥༦༩\(lrm)·\(lrm)༡༠\(lrm)·\(lrm)༢༤\(lrm)  \(lrm)༡༩:༥༩:༡༧.༨༠")
    }

    func testHebrewReadoutIsLatinDigits() {
        let s = Fixtures.sample("2026-10-24T19:59:22.790+03:00", calendar: .hebrew)
        XCTAssertEqual(Readout.text(sample: s, hourFormat: .h24, lang: .he, catalog: i18n), "5787·02·13  19:59:22.79")
    }

    func testUTCOffsets() {
        let at = Fixtures.referenceInstant
        XCTAssertEqual(Readout.utcOffset(timeZone: Fixtures.moscow, at: at), "UTC+03:00")
        XCTAssertEqual(Readout.utcOffset(timeZone: TimeZone(identifier: "America/New_York")!, at: at), "UTC−04:00")
        XCTAssertEqual(Readout.utcOffset(timeZone: TimeZone(identifier: "Asia/Kolkata")!, at: at), "UTC+05:30")
        XCTAssertEqual(Readout.utcOffset(timeZone: TimeZone(identifier: "Asia/Kathmandu")!, at: at), "UTC+05:45")
        XCTAssertEqual(Readout.utcOffset(timeZone: TimeZone(identifier: "UTC")!, at: at), "UTC+00:00")
    }

    func testPad2() {
        XCTAssertEqual(Readout.pad2(0), "00")
        XCTAssertEqual(Readout.pad2(7), "07")
        XCTAssertEqual(Readout.pad2(59), "59")
        XCTAssertEqual(Readout.pad2(2026), "2026")
    }
}
