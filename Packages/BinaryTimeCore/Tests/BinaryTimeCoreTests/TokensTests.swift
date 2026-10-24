import Foundation
import XCTest
@testable import BinaryTimeCore

final class TokensTests: XCTestCase {
    let tokens = Fixtures.tokens

    func testColoursAndOpacities() {
        XCTAssertEqual(tokens.version, "1.0.0")
        XCTAssertEqual(tokens.ink, "#000000")
        XCTAssertEqual(tokens.paper, "#FFFFFF")
        XCTAssertEqual(tokens.opacity.full, 1)
        XCTAssertEqual(tokens.opacity.mid, 0.66)
        XCTAssertEqual(tokens.opacity.low, 0.42)
        XCTAssertEqual(tokens.opacity.ghost, 0.22)
        XCTAssertEqual(tokens.opacity.rule, 0.5)
        XCTAssertEqual(tokens.opacity(named: "mid"), 0.66)
    }

    func testFonts() {
        XCTAssertEqual(tokens.fontStack.first, "JetBrains Mono")
        XCTAssertEqual(tokens.fontStack.prefix(5), ["JetBrains Mono", "Noto Sans Hebrew", "Noto Sans Arabic", "Noto Serif Tibetan", "Noto Sans JP"])
        XCTAssertEqual(tokens.fontWeights, ["light": 300, "regular": 400, "semibold": 600])
    }

    func testTypeScale() {
        XCTAssertEqual(tokens.type.base.source, "clamp(11px, 1.45cqmin, 22px)")
        XCTAssertEqual(tokens.type.kicker.tracking, 0.18)
        XCTAssertTrue(tokens.type.kicker.uppercase)
        XCTAssertEqual(tokens.type.kicker.opacity, 0.66)
        XCTAssertEqual(tokens.type.kicker.weight, 400)
        XCTAssertEqual(tokens.type.value.weight, 600)
        XCTAssertEqual(tokens.type.value.opacity, 1)
        XCTAssertEqual(tokens.type.rowLabelWeightDate, 400)
        XCTAssertEqual(tokens.type.rowLabelWeightTime, 600)
        XCTAssertEqual(tokens.type.rowLabel.tracking, 0.18)
        XCTAssertEqual(tokens.type.rowSub.opacity, 0.66)
        XCTAssertEqual(tokens.type.decimalWeightTime, 400)
        XCTAssertEqual(tokens.type.decimalWeightDate, 300)
        XCTAssertEqual(tokens.type.decimalTime.source, "min(b * 0.62, 2.4em)")
        XCTAssertEqual(tokens.type.placeOpacity, 0.66)
        XCTAssertEqual(tokens.type.separator.tracking, 0.24)
        XCTAssertEqual(tokens.type.readoutWeight, 300)
        XCTAssertEqual(tokens.type.readoutTracking, 0.08)
        XCTAssertEqual(tokens.type.button.tracking, 0.14)
        XCTAssertTrue(tokens.type.button.uppercase)
    }

    func testSpaceAndProseReaders() {
        XCTAssertEqual(tokens.space.pad.source, "clamp(16px, 4.2cqmin, 64px)")
        XCTAssertEqual(tokens.space.separatorMarginFactor, 1.2)
        XCTAssertEqual(tokens.space.separatorMarginFactorNarrow, 0.6)
        XCTAssertEqual(tokens.space.dateRowGapFactor, 0.6)
        XCTAssertEqual(try tokens.space.chromeGap.evaluate(in: ExpressionEnvironment(width: 1, height: 1)), 24)
    }

    func testBitTokens() {
        XCTAssertEqual(tokens.bit.dateScale, 0.56)
        XCTAssertEqual(tokens.bit.offOutlineFactor, 0.055)
        XCTAssertEqual(tokens.bit.offOutlineMinimum, 1)
        XCTAssertEqual(tokens.bit.voidScale, 0.1)
        XCTAssertEqual(tokens.bit.squareRadius.source, "max(2px, b * 0.12)")
    }

    func testMotion() {
        XCTAssertEqual(tokens.motion.bit, 0.18, accuracy: 1e-12)
        XCTAssertEqual(tokens.motion.theme, 0.6, accuracy: 1e-12)
        XCTAssertEqual(tokens.motion.control, 0.2, accuracy: 1e-12)
        XCTAssertEqual(tokens.motion.locationPulse, 2)
        XCTAssertEqual(tokens.motion.pulseMinimumOpacity, 0.2)
    }

    func testButtonAndBreakpoint() {
        XCTAssertEqual(tokens.button.minHeight, 44)
        XCTAssertEqual(tokens.button.paddingX, 16)
        XCTAssertEqual(tokens.button.gap, 8)
        XCTAssertEqual(tokens.button.opacityRest, 0.66)
        XCTAssertEqual(tokens.button.opacityHover, 1)
        XCTAssertEqual(tokens.narrowBreakpoint, 680)
    }

    func testLoaderRejectsChangedProse() throws {
        var json = try JSONSerialization.jsonObject(with: Fixtures.data("design/tokens.json")) as! [String: Any]
        var bit = json["bit"] as! [String: Any]
        var states = bit["states"] as! [String: Any]
        states["off"] = "outline thin fg"
        bit["states"] = states
        json["bit"] = bit
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try Tokens.load(from: data)) { error in
            guard case TokensError.unparseable(let path, _)? = error as? TokensError else { return XCTFail("\(error)") }
            XCTAssertEqual(path, "bit.states.off")
        }
    }

    func testLoaderReportsMissingKeys() throws {
        var json = try JSONSerialization.jsonObject(with: Fixtures.data("design/tokens.json")) as! [String: Any]
        json["space"] = nil
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try Tokens.load(from: data)) { error in
            XCTAssertEqual(error as? TokensError, .missing("space.separatorMargin"))
        }
    }
}
