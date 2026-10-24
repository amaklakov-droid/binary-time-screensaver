import Foundation
import XCTest
@testable import BinaryTimeCore

final class SettingsTests: XCTestCase {
    func testDefaultsMatchSpec() {
        let s = Settings.default
        XCTAssertEqual(s.language, .auto)
        XCTAssertEqual(s.hourFormat, .h24)
        XCTAssertEqual(s.calendar, .auto)
        XCTAssertEqual(s.location, .auto)
        XCTAssertEqual(s.theme, .dark)
        XCTAssertEqual(s.bitShape, .dot)
        XCTAssertTrue(s.showControls)
        XCTAssertFalse(s.onlineVPNCheck)
        XCTAssertEqual(s.apiKey, "")
    }

    func testDictionaryRoundTrip() {
        var s = Settings()
        s.language = .fixed(.ar)
        s.hourFormat = .h12
        s.calendar = .islamic
        s.location = .vpn
        s.theme = .light
        s.bitShape = .square
        s.showControls = false
        s.onlineVPNCheck = true
        s.apiKey = "k"
        let restored = Settings(dictionary: s.dictionaryRepresentation)
        XCTAssertEqual(restored, s)
        XCTAssertEqual(Set(s.dictionaryRepresentation.keys), Set(Settings.Key.allCases.map(\.rawValue)))
    }

    func testMalformedValuesFallBackToDefaults() {
        let s = Settings(dictionary: ["lang": "xx", "hourFormat": "13", "calendar": "persian", "theme": 42, "bitShape": "hex"])
        XCTAssertEqual(s, .default)
        XCTAssertEqual(Settings(dictionary: ["hourFormat": "12"]).hourFormat, .h12)
        XCTAssertEqual(Settings(dictionary: ["hourFormat": 12]).hourFormat, .h12)
    }

    func testLanguageSettingRawValues() {
        XCTAssertEqual(LanguageSetting(rawValue: "he"), .fixed(.he))
        XCTAssertEqual(LanguageSetting(rawValue: "auto"), .auto)
        XCTAssertEqual(LanguageSetting(rawValue: "klingon"), .auto)
        XCTAssertEqual(LanguageSetting.fixed(.bo).rawValue, "bo")
        XCTAssertEqual(LanguageSetting.auto.resolve(preferredLanguages: ["ja-JP"]), .ja)
        XCTAssertEqual(LanguageSetting.fixed(.ru).resolve(preferredLanguages: ["ja-JP"]), .ru)
    }
}
