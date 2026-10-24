import Foundation
import XCTest
@testable import BinaryTimeCore

final class I18nTests: XCTestCase {
    let i18n = Fixtures.i18n

    func testCatalogCoversAllSixLanguages() {
        XCTAssertEqual(i18n.languages, Language.allCases.map(\.rawValue), "Enum order must match switcher order in i18n.json")
        for lang in Language.allCases {
            let t = i18n.strings(lang)
            XCTAssertEqual(t.labels.count, 7, lang.rawValue)
            for cal in CalendarID.allCases {
                XCTAssertFalse(i18n.calendarName(cal, lang).isEmpty, "\(lang) \(cal)")
                XCTAssertFalse(i18n.era(cal, lang).isEmpty, "\(lang) \(cal)")
            }
            XCTAssertFalse(i18n.hourFormatName(.h12, lang).isEmpty)
            XCTAssertFalse(i18n.hourFormatName(.h24, lang).isEmpty)
            XCTAssertTrue(t.monthOf.contains("{n}"), lang.rawValue)
            XCTAssertTrue(t.h24.contains("{n}"), lang.rawValue)
        }
    }

    func testMetaRules() {
        XCTAssertEqual(i18n.meta(.he).dir, .rtl)
        XCTAssertEqual(i18n.meta(.ar).dir, .rtl)
        XCTAssertEqual(i18n.meta(.en).dir, .ltr)
        XCTAssertEqual(i18n.meta(.ar).digits, .arab)
        XCTAssertEqual(i18n.meta(.bo).digits, .tibt)
        XCTAssertEqual(i18n.meta(.ja).digits, .latn)
        XCTAssertTrue(i18n.meta(.en).caps)
        XCTAssertFalse(i18n.meta(.ar).caps)
        XCTAssertEqual(i18n.meta(.bo).lineHeight, 1.7)
        XCTAssertEqual(i18n.intlLocaleIdentifier(.bo), "en")
        XCTAssertEqual(i18n.intlLocaleIdentifier(.he), "he")
        XCTAssertTrue(i18n.meta(.he).review && i18n.meta(.ar).review && i18n.meta(.bo).review)
    }

    func testKindsFallBackForTibetan() {
        XCTAssertNil(i18n.strings(.bo).kinds)
        XCTAssertEqual(i18n.kinds(.bo), i18n.kinds(.en))
        XCTAssertEqual(i18n.kinds(.ru).count, 14)
        XCTAssertNoThrow(try Fixtures.catalog.validate(against: i18n))
    }

    func testDigitMapping() {
        XCTAssertEqual(i18n.digits("2026·10·24", .ar), "٢٠٢٦·١٠·٢٤")
        XCTAssertEqual(i18n.digits("1/100 s", .bo), "༡/༡༠༠ s")
        XCTAssertEqual(i18n.digits("1024", .ru), "1024")
        XCTAssertEqual(Digits.map("abc", to: "٠١٢٣٤٥٦٧٨٩"), "abc")
        XCTAssertEqual(Digits.map("12", to: "bad"), "12", "Malformed digit set leaves text unchanged")
    }

    func testDefaultLanguageResolution() {
        XCTAssertEqual(Language.resolveDefault(preferred: ["en-RU", "ru-RU"]), .en)
        XCTAssertEqual(Language.resolveDefault(preferred: ["ru-RU", "en"]), .ru)
        XCTAssertEqual(Language.resolveDefault(preferred: ["iw-IL"]), .he)
        XCTAssertEqual(Language.resolveDefault(preferred: ["he"]), .he)
        XCTAssertEqual(Language.resolveDefault(preferred: ["zh-Hans-CN", "ja-JP"]), .ja)
        XCTAssertEqual(Language.resolveDefault(preferred: ["zh-Hans-CN"]), .en)
        XCTAssertEqual(Language.resolveDefault(preferred: []), .en)
        XCTAssertEqual(Language.resolveDefault(preferred: ["bo_CN"]), .bo)
    }

    func testSwitcherOrderWraps() {
        XCTAssertEqual(Language.en.next, .ru)
        XCTAssertEqual(Language.ja.next, .en)
    }

    func testShortCalendarName() {
        XCTAssertEqual(i18n.calendarShortName(.islamic, .en), "Islamic")
        XCTAssertEqual(i18n.calendarShortName(.gregory, .ru), "Григорианский")
    }

    func testValidationRejectsBrokenCatalog() {
        var broken = i18n
        broken.strings["ru"]?.labels.removeLast()
        XCTAssertThrowsError(try broken.validate())
    }
}
