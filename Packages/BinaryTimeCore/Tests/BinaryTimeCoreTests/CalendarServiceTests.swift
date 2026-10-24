import Foundation
import XCTest
@testable import BinaryTimeCore

final class CalendarServiceTests: XCTestCase {
    let moscow = Fixtures.moscow
    let reference = Fixtures.referenceInstant

    func testReferenceDateInAllFourCalendars() {
        let g = CalendarService.dateParts(reference, calendar: .gregory, timeZone: moscow)
        XCTAssertEqual([g.year, g.month, g.day, g.monthsInYear], [2026, 10, 24, 12])
        XCTAssertEqual(g.weekday, 6, "Saturday")

        let i = CalendarService.dateParts(reference, calendar: .islamic, timeZone: moscow)
        XCTAssertEqual([i.year, i.month, i.day, i.monthsInYear], [1448, 5, 13, 12])

        let h = CalendarService.dateParts(reference, calendar: .hebrew, timeZone: moscow)
        XCTAssertEqual([h.year, h.month, h.day, h.monthsInYear], [5787, 2, 13, 13])
        XCTAssertTrue(h.isLeapYear)

        let b = CalendarService.dateParts(reference, calendar: .buddhist, timeZone: moscow)
        XCTAssertEqual([b.year, b.month, b.day, b.monthsInYear], [2569, 10, 24, 12])
    }

    func testHebrewLeapYearOrdinals() {
        // 5787 is a leap year: Adar I = 6, Adar II = 7, Elul = 13.
        let adarI = CalendarService.dateParts(Fixtures.date("2027-02-15T12:00:00+03:00"), calendar: .hebrew, timeZone: moscow)
        XCTAssertEqual([adarI.year, adarI.month, adarI.monthsInYear], [5787, 6, 13])
        let adarII = CalendarService.dateParts(Fixtures.date("2027-03-15T12:00:00+03:00"), calendar: .hebrew, timeZone: moscow)
        XCTAssertEqual([adarII.year, adarII.month], [5787, 7])
        let elul = CalendarService.dateParts(Fixtures.date("2027-09-05T12:00:00+03:00"), calendar: .hebrew, timeZone: moscow)
        XCTAssertEqual([elul.year, elul.month, elul.monthsInYear], [5787, 13, 13])
    }

    func testHebrewNonLeapYearOrdinals() {
        // 5788 is not a leap year: Adar = 6, Nisan = 7, Elul = 12; Foundation reports them as 7, 8, 13.
        let adar = CalendarService.dateParts(Fixtures.date("2028-03-15T12:00:00+03:00"), calendar: .hebrew, timeZone: moscow)
        XCTAssertEqual([adar.year, adar.month, adar.monthsInYear], [5788, 6, 12])
        XCTAssertFalse(adar.isLeapYear)
        let elul = CalendarService.dateParts(Fixtures.date("2028-09-01T12:00:00+03:00"), calendar: .hebrew, timeZone: moscow)
        XCTAssertEqual([elul.year, elul.month, elul.monthsInYear], [5788, 12, 12])
        let heshvan = CalendarService.dateParts(Fixtures.date("2027-11-01T12:00:00+03:00"), calendar: .hebrew, timeZone: moscow)
        XCTAssertEqual([heshvan.year, heshvan.month], [5788, 2], "Months before Adar are unchanged")
    }

    func testHebrewOrdinalMapping() {
        XCTAssertEqual(CalendarService.hebrewOrdinalMonth(foundationMonth: 7, isLeapYear: false), 6)
        XCTAssertEqual(CalendarService.hebrewOrdinalMonth(foundationMonth: 13, isLeapYear: false), 12)
        XCTAssertEqual(CalendarService.hebrewOrdinalMonth(foundationMonth: 5, isLeapYear: false), 5)
        XCTAssertEqual(CalendarService.hebrewOrdinalMonth(foundationMonth: 7, isLeapYear: true), 7)
        XCTAssertEqual(CalendarService.hebrewOrdinalMonth(foundationMonth: 13, isLeapYear: true), 13)
    }

    func testArithmeticLeapRuleAgreesWithFoundation() {
        for year in 5780...5800 {
            // Any date inside the Hebrew year: build 1 Tishri of that year.
            let cal = CalendarService.calendar(.hebrew, timeZone: moscow)
            var c = DateComponents(); c.year = year; c.month = 1; c.day = 15
            let date = cal.date(from: c)!
            XCTAssertEqual(
                CalendarService.hebrewIsLeapYear(year, containing: date, calendar: cal),
                CalendarService.hebrewIsLeapYear(arithmetic: year),
                "year \(year)"
            )
        }
    }

    func testAutoResolutionPrefersOSCalendar() {
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: .hebrew, timeZone: moscow), .hebrew)
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: .buddhist, timeZone: TimeZone(identifier: "Asia/Riyadh")!), .buddhist)
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: .islamicUmmAlQura, timeZone: moscow), .islamic)
    }

    func testAutoResolutionByTimeZone() {
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: .gregorian, timeZone: TimeZone(identifier: "Asia/Riyadh")!), .gregory, "OS Gregorian is itself one of the four and wins")
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: nil, timeZone: TimeZone(identifier: "Asia/Riyadh")!), .islamic)
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: nil, timeZone: TimeZone(identifier: "Asia/Jerusalem")!), .hebrew)
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: nil, timeZone: TimeZone(identifier: "Asia/Tel_Aviv")!), .hebrew)
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: nil, timeZone: TimeZone(identifier: "Asia/Bangkok")!), .buddhist)
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: nil, timeZone: moscow), .gregory)
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: .chinese, timeZone: TimeZone(identifier: "Asia/Bangkok")!), .buddhist, "Unsupported OS calendar falls through to the zone rule")
        XCTAssertEqual(CalendarService.resolveAuto(osCalendar: .persian, timeZone: TimeZone(identifier: "Asia/Tehran")!), .gregory)
    }

    func testFixedSettingIgnoresContext() {
        XCTAssertEqual(CalendarService.resolve(.hebrew, osCalendar: .gregorian, timeZone: moscow), .hebrew)
        XCTAssertEqual(CalendarService.resolve(.auto, osCalendar: nil, timeZone: moscow), .gregory)
        XCTAssertEqual(CalendarSetting.auto.fixed, nil)
        XCTAssertEqual(CalendarSetting.islamic.fixed, .islamic)
    }
}
