import AppKit
import CoreText
import XCTest
import BinaryTimeCore
@testable import BinaryTimeUI

/// The bundled OFL fonts register and resolve: JetBrains Mono at 300/400/600 and the Noto cascade per script.
final class FontRegistryTests: XCTestCase {
    static let fonts = SceneLayoutTests.resources.fonts

    func testBundleIsComplete() {
        XCTAssertTrue(Self.fonts.isComplete, "missing: \(Self.fonts.missingFamilies)")
        XCTAssertGreaterThanOrEqual(Self.fonts.registeredURLs.count, 7)
        XCTAssertEqual(Self.fonts.primaryFamily, "JetBrains Mono")
        XCTAssertEqual(Self.fonts.cascadeFamilies, ["Noto Sans Hebrew", "Noto Sans Arabic", "Noto Serif Tibetan", "Noto Sans JP"])
    }

    func testWeightsResolveToJetBrainsMonoFaces() {
        let expected: [Int: String] = [300: "JetBrainsMono-Light", 400: "JetBrainsMono-Regular", 600: "JetBrainsMono-SemiBold"]
        for (weight, postScriptName) in expected {
            let font = Self.fonts.font(weight: weight, size: 20)
            XCTAssertEqual(font.fontName, postScriptName, "weight \(weight)")
            XCTAssertEqual(font.familyName, "JetBrains Mono")
        }
    }

    func testCascadePicksNotoPerScript() {
        let font = Self.fonts.font(weight: 400, size: 20)
        func family(for text: String) -> String {
            let ct = CTFontCreateForString(font as CTFont, text as CFString, CFRange(location: 0, length: (text as NSString).length))
            return CTFontCopyFamilyName(ct) as String
        }
        XCTAssertEqual(family(for: "שבת"), "Noto Sans Hebrew")
        XCTAssertEqual(family(for: "السبت"), "Noto Sans Arabic")
        XCTAssertEqual(family(for: "དུས་ཚོད།"), "Noto Serif Tibetan")
        XCTAssertEqual(family(for: "時刻"), "Noto Sans JP")
        XCTAssertEqual(family(for: "2026"), "JetBrains Mono")
        XCTAssertEqual(family(for: "суббота"), "JetBrains Mono", "Cyrillic is in JetBrains Mono")
    }

    func testCascadeFacesFollowTheWeight() {
        for (weight, suffix) in [(300, "Light"), (400, "Regular"), (600, "SemiBold")] {
            let font = Self.fonts.font(weight: weight, size: 20)
            let text = "שבת"
            let ct = CTFontCreateForString(font as CTFont, text as CFString, CFRange(location: 0, length: 3))
            let name = CTFontCopyPostScriptName(ct) as String
            XCTAssertTrue(name.hasSuffix(suffix) || name.contains(suffix), "weight \(weight): Hebrew face is \(name)")
        }
    }

    func testTabularDigitsHaveEqualAdvances() {
        let font = Self.fonts.font(weight: 300, size: 40)
        let widths = (0...9).map { NSAttributedString(string: String($0), attributes: [.font: font]).size().width }
        XCTAssertEqual(widths.min()!, widths.max()!, accuracy: 0.01)
    }
}
