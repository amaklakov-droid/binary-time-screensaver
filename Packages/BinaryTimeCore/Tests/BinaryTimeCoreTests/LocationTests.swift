import Foundation
import XCTest
@testable import BinaryTimeCore

final class LocationTests: XCTestCase {
    let resolver = LocationResolver(i18n: Fixtures.i18n, zones: Fixtures.zones)
    let moscow = Fixtures.moscow

    // MARK: Zone table

    func testBundledZoneTableParses() {
        XCTAssertGreaterThan(Fixtures.zones.count, 300)
        XCTAssertEqual(Fixtures.zones.countryCode(forZone: "Europe/Moscow"), "RU")
        XCTAssertEqual(Fixtures.zones.countryCode(forZone: "Asia/Bangkok"), "TH")
        XCTAssertEqual(Fixtures.zones.countryCode(forZone: "Asia/Jerusalem"), "IL")
        XCTAssertEqual(Fixtures.zones.countryCode(forZone: "Asia/Tel_Aviv"), "IL", "Alias resolves to the canonical zone")
        XCTAssertEqual(Fixtures.zones.countryCode(forZone: "America/Argentina/Buenos_Aires"), "AR")
        XCTAssertNil(Fixtures.zones.countryCode(forZone: "UTC"))
        XCTAssertNil(Fixtures.zones.countryCode(forZone: "Etc/GMT+3"))
    }

    func testZone1970FormatTakesHomeCountry() {
        let text = """
        # comment line
        TH,CX,KH,LA,VN\t+1345+10031\tAsia/Bangkok\tnorth Vietnam
        RU\t+554521+0373704\tEurope/Moscow\tMSK+00 - Moscow area
        """
        let table = ZoneTable(parsing: text)
        XCTAssertEqual(table.count, 2)
        XCTAssertEqual(table.countryCode(forZone: "Asia/Bangkok"), "TH")
        XCTAssertEqual(table.countryCode(forZone: "Europe/Moscow"), "RU")
    }

    func testCityNames() {
        XCTAssertEqual(ZoneTable.cityName(forZone: "Europe/Moscow"), "Moscow")
        XCTAssertEqual(ZoneTable.cityName(forZone: "America/Argentina/Buenos_Aires"), "Buenos Aires")
        XCTAssertEqual(ZoneTable.cityName(forZone: "America/New_York"), "New York")
        XCTAssertNil(ZoneTable.cityName(forZone: "UTC"))
        XCTAssertNil(ZoneTable.cityName(forZone: "GMT"))
        XCTAssertNil(ZoneTable.cityName(forZone: "Etc/GMT+3"))
    }

    // MARK: Real place

    func testTimeZoneBranchLocalizesCountry() {
        let ru = resolver.model(for: .timeZone(moscow), lang: .ru)
        XCTAssertEqual(ru, LocationModel(tag: "По часовому поясу", l1: "Moscow · Россия", l2: "Europe/Moscow"))
        let en = resolver.model(for: .timeZone(moscow), lang: .en)
        XCTAssertEqual(en.l1, "Moscow · Russia")
        let he = resolver.model(for: .timeZone(moscow), lang: .he)
        XCTAssertEqual(he.l1, "Moscow · רוסיה")
        let ar = resolver.model(for: .timeZone(moscow), lang: .ar)
        XCTAssertEqual(ar.l1, "Moscow · روسيا")
        XCTAssertEqual(ar.tag, "حسب المنطقة الزمنية")
    }

    func testTibetanUsesEnglishRegionNames() {
        // i18n.meta.bo.intlFallback = "en" — matches reference screenshot 06.
        let bo = resolver.model(for: .timeZone(moscow), lang: .bo)
        XCTAssertEqual(bo.l1, "Moscow · Russia")
        XCTAssertEqual(bo.tag, "དུས་ཁུལ་ལྟར།")
    }

    func testUnknownBranch() {
        let utc = resolver.model(for: .timeZone(TimeZone(identifier: "UTC")!), lang: .en)
        XCTAssertEqual(utc, LocationModel(tag: "By time zone", l1: "Location unknown", l2: "GMT"))
        let ru = resolver.model(for: .timeZone(TimeZone(identifier: "Etc/GMT-3")!), lang: .ru)
        XCTAssertEqual(ru.l1, "Место не определено")
        XCTAssertEqual(ru.l2, "Etc/GMT-3")
    }

    func testCityWithoutCountryShowsCityAlone() {
        let resolver = LocationResolver(i18n: Fixtures.i18n, zones: ZoneTable(entries: [:]))
        let model = resolver.model(for: .timeZone(moscow), lang: .en)
        XCTAssertEqual(model.l1, "Moscow")
        XCTAssertEqual(model.l2, "Europe/Moscow")
    }

    func testCoordinatesBranch() {
        let coords = Coordinates(latitude: 55.7558, longitude: 37.6173)
        let model = resolver.model(for: .timeZone(moscow, coordinates: coords), lang: .en)
        XCTAssertEqual(model, LocationModel(tag: "Geolocation", l1: "Moscow · Russia", l2: "55.76° N · 37.62° E", l3: "Europe/Moscow"))
        XCTAssertEqual(LocationResolver.formatCoordinates(Coordinates(latitude: -33.8688, longitude: -70.6)), "33.87° S · 70.60° W")
        let noCity = resolver.model(for: .timeZone(TimeZone(identifier: "UTC")!, coordinates: coords), lang: .en)
        XCTAssertEqual(noCity.l1, "55.76° N · 37.62° E")
        XCTAssertEqual(noCity.l2, "GMT")
        XCTAssertEqual(noCity.l3, "")
    }

    // MARK: Space

    func testSurfaceObjectMatchesScreenshot07() {
        let model = resolver.model(for: .space(Fixtures.object("olympus")), lang: .ja)
        XCTAssertEqual(model, LocationModel(tag: "VPN · 実際の位置は非表示", l1: "オリンポス山（火星）", l2: "18.65° N · 226.2° E", l3: "楯状火山"))
    }

    func testDeepSkyObjectMatchesScreenshot10() {
        let model = resolver.model(for: .space(Fixtures.object("trappist1")), lang: .ja)
        XCTAssertEqual(model.l1, "トラピスト1")
        XCTAssertEqual(model.l2, "RA 23h06m29s · Dec −05°02′29″")
        XCTAssertEqual(model.l3, "惑星系 · 40 光年")
    }

    func testDesignationApproxAndDigits() {
        let en = resolver.model(for: .space(Fixtures.object("betelgeuse")), lang: .en)
        XCTAssertEqual(en.l3, "Red supergiant · α Ori · ≈550 ly")
        let ar = resolver.model(for: .space(Fixtures.object("sirius")), lang: .ar)
        XCTAssertEqual(ar.l3, "نجم · α CMa · ٨.٦ سنة ضوئية")
        let bo = resolver.model(for: .space(Fixtures.object("proxima")), lang: .bo)
        XCTAssertEqual(bo.l1, "Proxima Centauri", "No Tibetan name → English")
        XCTAssertEqual(bo.l3, "Red dwarf · α Cen C · ༤.༢༤ འོད་ལོ།")
    }

    func testDistanceGrouping() {
        XCTAssertEqual(resolver.formatDistance(2_500_000, lang: .en), "2,500,000")
        XCTAssertEqual(resolver.formatDistance(2_500_000, lang: .ja), "2,500,000")
        let ru = resolver.formatDistance(2_500_000, lang: .ru)
        XCTAssertEqual(ru.filter(\.isNumber), "2500000")
        XCTAssertEqual(ru.count, 9, "Two grouping separators: \(ru.unicodeScalars.map { String($0.value, radix: 16) })")
        XCTAssertEqual(resolver.formatDistance(4.24, lang: .en), "4.24")
        XCTAssertEqual(resolver.formatDistance(1344, lang: .en), "1,344")
    }

    func testEveryObjectRendersInEveryLanguage() {
        for object in Fixtures.catalog.objects {
            for lang in Language.allCases {
                let m = resolver.model(for: .space(object), lang: lang)
                XCTAssertFalse(m.l1.isEmpty, "\(object.id) \(lang)")
                XCTAssertFalse(m.l2.isEmpty, "\(object.id) \(lang)")
                XCTAssertFalse(m.l3.isEmpty, "\(object.id) \(lang)")
                XCTAssertEqual(m.tag, Fixtures.i18n.strings(lang).vpn)
            }
        }
    }
}
