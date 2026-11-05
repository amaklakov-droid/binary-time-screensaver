import Foundation
import XCTest
@testable import BinaryTimeCore

final class ScreenPresenterTests: XCTestCase {
    let presenter = ScreenPresenter(i18n: Fixtures.i18n)
    let resolver = LocationResolver(i18n: Fixtures.i18n, zones: Fixtures.zones)
    let moscow = Fixtures.moscow

    private func frame(_ iso: String, lang: Language, calendar: CalendarID, settings: Settings = .default) -> ScreenModel {
        let instant = Fixtures.date(iso)
        let sample = ClockSample.make(at: instant, timeZone: moscow, calendar: calendar)
        let location = settings.location == .vpn
            ? resolver.model(for: .space(Fixtures.object("olympus")), lang: lang)
            : resolver.model(for: .timeZone(moscow), lang: lang)
        let context = FrameContext(instant: instant, timeZone: moscow, language: lang, calendar: calendar, settings: settings, location: location)
        return presenter.model(sample: sample, context: context)
    }

    func testScreenshot01EnglishDark24h() {
        let m = frame("2026-10-24T19:59:17.800+03:00", lang: .en, calendar: .gregory)
        XCTAssertEqual(m.header, HeaderModel(title: "Binary time", calendarLine: "Gregorian · auto", dateLine: "Saturday, October 24, 2026"))
        XCTAssertEqual(m.location.l1, "Moscow · Russia")
        XCTAssertEqual(m.location.tag, "By time zone")
        XCTAssertEqual(m.columns, 11)
        XCTAssertEqual(m.placeValues, ["1024", "512", "256", "128", "64", "32", "16", "8", "4", "2", "1"])
        XCTAssertEqual(m.rows.map(\.label), ["Year", "Month", "Day", "Hours", "Minutes", "Seconds"])
        XCTAssertEqual(m.rows.map(\.sub), ["CE", "of 12", "Sat", "24-hour", "0–59", "0–59"])
        XCTAssertEqual(m.rows.map(\.decimal), ["2026", "10", "24", "19", "59", "17"])
        XCTAssertEqual(m.rows.map(\.bits), [11, 4, 5, 5, 6, 6])
        XCTAssertEqual(m.rows[0].states, "11111101010".map { $0 == "1" ? BitState.on : .off })
        XCTAssertEqual(m.rows[3].states.suffix(5).map { $0 == .on ? "1" : "0" }.joined(), "10011")
        XCTAssertEqual(Array(m.rows[3].states.prefix(6)), Array(repeating: BitState.void, count: 6))
        XCTAssertEqual(m.rows[0].accessibilityLabel, "Year 2026 — 11111101010")
        XCTAssertEqual(m.footer, FooterModel(readout: "2026·10·24  19:59:17", dayPeriod: "", utcOffset: "UTC+03:00"))
        XCTAssertEqual(m.separatorLabel, "Time")
        XCTAssertEqual(m.dateGroupLabel, "Date")
        XCTAssertEqual(m.direction, .ltr)
        XCTAssertTrue(m.caps)
        XCTAssertEqual(m.theme, .dark)
        XCTAssertEqual(m.bitShape, .dot)
        XCTAssertEqual(m.structureKey, "11|en")
        XCTAssertEqual(m.controls, ControlsModel(language: "English", languageAccessibility: "Language: English", hourFormat: "24-hour", calendar: "Calendar: auto", location: "Location: auto", invert: "Invert", groupLabel: "Display settings"))
    }

    func testScreenshot03RussianLight12hSquare() {
        var settings = Settings.default
        settings.hourFormat = .h12
        settings.theme = .light
        settings.bitShape = .square
        let m = frame("2026-10-24T19:59:21.090+03:00", lang: .ru, calendar: .gregory, settings: settings)
        XCTAssertEqual(m.header.calendarLine, "Григорианский · авто")
        XCTAssertEqual(plainSpaces(m.header.dateLine), "суббота, 24 октября 2026 г.")
        XCTAssertEqual(m.rows[3].sub, "PM")
        XCTAssertEqual(m.rows[3].decimal, "07")
        XCTAssertEqual(m.rows[3].bits, 4)
        XCTAssertEqual(m.rows[3].states.suffix(4).map { $0 == .on ? "1" : "0" }.joined(), "0111")
        XCTAssertEqual(m.footer.readout, "2026·10·24  07:59:21")
        XCTAssertEqual(m.footer.dayPeriod, "PM")
        XCTAssertEqual(m.controls.hourFormat, "12-часовой")
        XCTAssertEqual(m.theme, .light)
        XCTAssertEqual(m.bitShape, .square)
        XCTAssertEqual(m.rows.map(\.sub).prefix(3), ["н. э.", "из 12", "Сб"])
    }

    func testScreenshot04HebrewRTL() {
        let m = frame("2026-10-24T19:59:22.790+03:00", lang: .he, calendar: .hebrew)
        XCTAssertEqual(m.direction, .rtl)
        XCTAssertFalse(m.caps)
        XCTAssertEqual(m.columns, 13)
        XCTAssertEqual(m.placeValues.first, "4096")
        XCTAssertEqual(m.rows[0].decimal, "5787")
        XCTAssertEqual(m.rows[1].sub, "מתוך 13", "5787 is a leap year")
        XCTAssertEqual(m.rows[1].decimal, "02")
        XCTAssertEqual(m.rows[2].decimal, "13")
        XCTAssertEqual(m.rows[2].sub, "שבת")
        XCTAssertEqual(m.footer.readout, "5787·02·13  19:59:22")
        XCTAssertEqual(m.location.l1, "Moscow · רוסיה")
        XCTAssertEqual(m.structureKey, "13|he")
    }

    func testScreenshot05ArabicIslamic12h() {
        var settings = Settings.default
        settings.hourFormat = .h12
        settings.theme = .light
        let m = frame("2026-10-24T19:59:24.420+03:00", lang: .ar, calendar: .islamic, settings: settings)
        XCTAssertEqual(m.digits, .arab)
        XCTAssertEqual(m.columns, 11)
        XCTAssertEqual(m.placeValues.first, "١٠٢٤")
        XCTAssertEqual(m.rows.map(\.decimal), ["١٤٤٨", "٠٥", "١٣", "٠٧", "٥٩", "٢٤"])
        XCTAssertEqual(m.rows[3].sub, "م")
        XCTAssertEqual(m.rows[1].sub, "من ١٢")
        XCTAssertEqual(m.footer.dayPeriod, "م")
        XCTAssertTrue(m.footer.readout.hasPrefix("١٤٤٨"))
        XCTAssertEqual(m.header.calendarLine, "هجري · أم القرى · تلقائي")
    }

    func testScreenshot06TibetanBuddhist() {
        let m = frame("2026-10-24T19:59:26.090+03:00", lang: .bo, calendar: .buddhist)
        XCTAssertEqual(m.columns, 12)
        XCTAssertEqual(m.placeValues.first, "༢༠༤༨")
        XCTAssertEqual(m.rows[0].decimal, "༢༥༦༩")
        XCTAssertEqual(m.rows[0].sub, "སངས་རྒྱས་ལོ།")
        XCTAssertEqual(m.rows[1].sub, "༡༢ ཡི་ནང་ནས།")
        XCTAssertEqual(m.rows[2].sub, "གཟའ་སྤེན་པ།")
        XCTAssertEqual(m.rows[3].sub, "ཆུ་ཚོད་ ༢༤")
        XCTAssertEqual(m.lineHeight, 1.7)
        XCTAssertEqual(m.location.l1, "Moscow · Russia")
        XCTAssertEqual(m.header.dateLine, "ལོ་༢༥༦༩ ཟླ་༡༠ ཚེས་༢༤ · གཟའ་སྤེན་པ།")
    }

    func testScreenshot07JapaneseVPN() {
        var settings = Settings.default
        settings.location = .vpn
        let m = frame("2026-10-24T19:59:27.700+03:00", lang: .ja, calendar: .gregory, settings: settings)
        XCTAssertEqual(m.header.calendarLine, "グレゴリオ暦 · 自動")
        XCTAssertEqual(m.location, LocationModel(tag: "VPN · 実際の位置は非表示", l1: "オリンポス山（火星）", l2: "18.65° N · 226.2° E", l3: "楯状火山"))
        XCTAssertEqual(m.rows.map(\.label), ["年", "月", "日", "時", "分", "秒"])
        XCTAssertEqual(m.rows[3].sub, "24時間制")
        XCTAssertEqual(m.controls.location, "位置: VPN")
        XCTAssertEqual(m.controls.calendar, "暦: 自動")
    }

    func testFixedCalendarDropsAutoSuffixAndShortensPill() {
        var settings = Settings.default
        settings.calendar = .islamic
        let m = frame("2026-10-24T19:59:17.800+03:00", lang: .en, calendar: .islamic, settings: settings)
        XCTAssertEqual(m.header.calendarLine, "Islamic · Umm al-Qura")
        XCTAssertEqual(m.controls.calendar, "Calendar: Islamic")
        XCTAssertEqual(m.rows[0].sub, "AH")
    }

    func testSixBitRowsKeepOneVoidWhenColumnsAreSeven() {
        let instant = Fixtures.date("2026-10-24T19:59:17.800+03:00")
        var sample = ClockSample.make(at: instant, timeZone: moscow, calendar: .gregory)
        sample.date.year = 100 // forces w = 7
        let context = FrameContext(instant: instant, timeZone: moscow, language: .en, calendar: .gregory, settings: .default, location: LocationModel(tag: "", l1: "", l2: ""))
        let m = presenter.model(sample: sample, context: context)
        XCTAssertEqual(m.columns, 7)
        XCTAssertEqual(m.rows[5].states.filter { $0 == .void }.count, 1, "seconds: 6 bits in 7 columns")
        XCTAssertEqual(m.rows[0].states.filter { $0 == .void }.count, 0)
    }

    func testDateAndTimeRowSplit() {
        let m = frame("2026-10-24T19:59:17.800+03:00", lang: .en, calendar: .gregory)
        XCTAssertEqual(m.dateRows.map(\.metric), [.year, .month, .day])
        XCTAssertEqual(m.timeRows.map(\.metric), [.hours, .minutes, .seconds])
    }
}
