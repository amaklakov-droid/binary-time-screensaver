import Foundation
import XCTest
@testable import BinaryTimeCore

/// These depend on the system's ICU data; expected values were taken from macOS 26 and the reference screenshots.
final class DateTextTests: XCTestCase {
    let formatter = DateTextFormatter(catalog: Fixtures.i18n)
    let instant = Fixtures.referenceInstant
    let moscow = Fixtures.moscow

    private func parts(_ cal: CalendarID) -> DateParts {
        CalendarService.dateParts(instant, calendar: cal, timeZone: moscow)
    }

    func testDateLinesMatchReferenceScreens() {
        XCTAssertEqual(formatter.dateLine(instant, parts: parts(.gregory), calendar: .gregory, lang: .en, timeZone: moscow), "Saturday, October 24, 2026")
        XCTAssertEqual(plainSpaces(formatter.dateLine(instant, parts: parts(.gregory), calendar: .gregory, lang: .ru, timeZone: moscow)), "суббота, 24 октября 2026 г.")
        XCTAssertEqual(formatter.dateLine(instant, parts: parts(.hebrew), calendar: .hebrew, lang: .he, timeZone: moscow), "יום שבת, 13 בחשון 5787")
        let arabic = formatter.dateLine(instant, parts: parts(.islamic), calendar: .islamic, lang: .ar, timeZone: moscow)
        XCTAssertTrue(arabic.contains("١٤٤٨"), arabic)
        XCTAssertTrue(arabic.contains("جمادى الأولى"), arabic)
        XCTAssertFalse(arabic.contains("1448"), "Digits must be Arabic-Indic")
        let japanese = formatter.dateLine(instant, parts: parts(.gregory), calendar: .gregory, lang: .ja, timeZone: moscow)
        XCTAssertTrue(japanese.hasPrefix("2026年10月24日"), japanese)
        XCTAssertTrue(japanese.contains("土曜日"), japanese)
    }

    func testTibetanDateLineUsesTemplateAndDigits() {
        let line = formatter.dateLine(instant, parts: parts(.buddhist), calendar: .buddhist, lang: .bo, timeZone: moscow)
        XCTAssertEqual(line, "ལོ་༢༥༦༩ ཟླ་༡༠ ཚེས་༢༤ · གཟའ་སྤེན་པ།")
    }

    func testWeekdayShort() {
        XCTAssertEqual(formatter.weekdayShort(instant, parts: parts(.gregory), lang: .en, timeZone: moscow), "Sat")
        XCTAssertEqual(formatter.weekdayShort(instant, parts: parts(.gregory), lang: .ru, timeZone: moscow), "Сб", "Apple ICU capitalizes; browser CLDR shows «сб»")
        XCTAssertEqual(formatter.weekdayShort(instant, parts: parts(.gregory), lang: .ja, timeZone: moscow), "土")
        XCTAssertEqual(formatter.weekdayShort(instant, parts: parts(.gregory), lang: .he, timeZone: moscow), "שבת")
        XCTAssertEqual(formatter.weekdayShort(instant, parts: parts(.gregory), lang: .ar, timeZone: moscow), "سبت", "Apple ICU short form; browser CLDR shows «السبت»")
        XCTAssertEqual(formatter.weekdayShort(instant, parts: parts(.gregory), lang: .bo, timeZone: moscow), "གཟའ་སྤེན་པ།")
    }

    func testDayPeriods() {
        XCTAssertEqual(formatter.dayPeriod(isPM: true, lang: .en), "PM")
        XCTAssertEqual(formatter.dayPeriod(isPM: false, lang: .en), "AM")
        XCTAssertEqual(formatter.dayPeriod(isPM: true, lang: .ru), "PM")
        XCTAssertEqual(formatter.dayPeriod(isPM: true, lang: .ar), "م")
        XCTAssertEqual(formatter.dayPeriod(isPM: false, lang: .ar), "ص")
        XCTAssertEqual(formatter.dayPeriod(isPM: true, lang: .ja), "午後")
        XCTAssertEqual(formatter.dayPeriod(isPM: true, lang: .bo), "ཕྱི་དྲོ།")
        XCTAssertEqual(formatter.dayPeriod(isPM: false, lang: .bo), "སྔ་དྲོ།")
    }

    func testHebrewMonthNameFollowsLeapStatus() {
        let leapAdar = Fixtures.date("2027-03-15T12:00:00+03:00")
        let plainAdar = Fixtures.date("2028-03-15T12:00:00+03:00")
        let leapLine = formatter.dateLine(leapAdar, parts: CalendarService.dateParts(leapAdar, calendar: .hebrew, timeZone: moscow), calendar: .hebrew, lang: .he, timeZone: moscow)
        let plainLine = formatter.dateLine(plainAdar, parts: CalendarService.dateParts(plainAdar, calendar: .hebrew, timeZone: moscow), calendar: .hebrew, lang: .he, timeZone: moscow)
        XCTAssertTrue(leapLine.contains("אדר ב׳"), leapLine)
        XCTAssertTrue(plainLine.contains("באדר "), plainLine)
        XCTAssertFalse(plainLine.contains("אדר ב"), plainLine)
    }
}
