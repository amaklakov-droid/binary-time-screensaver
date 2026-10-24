import Foundation
import XCTest
@testable import BinaryTimeCore

final class LayoutMetricsTests: XCTestCase {
    let tokens = Fixtures.tokens

    func testReferenceScreen1440x900() throws {
        let m = try LayoutMetrics.compute(width: 1440, height: 900, columns: 11, tokens: tokens)
        XCTAssertFalse(m.isNarrow)
        XCTAssertEqual(m.fontSize, 13.05, accuracy: 1e-9)
        XCTAssertEqual(m.pad, 37.8, accuracy: 1e-9)
        XCTAssertEqual(m.gap, 12.6, accuracy: 1e-9)
        XCTAssertEqual(m.labelColumn, 172.8, accuracy: 1e-9)
        XCTAssertEqual(m.decimalColumn, 129.6, accuracy: 1e-9)
        XCTAssertEqual(m.bit, 554.4 / 10.4, accuracy: 1e-9, "Height-limited: ≈53.3 pt, as on the reference screenshots")
        XCTAssertEqual(m.dateBit, m.bit * 0.56, accuracy: 1e-9)
        XCTAssertEqual(m.offOutline, m.bit * 0.055, accuracy: 1e-9)
        XCTAssertEqual(m.voidDot, m.bit * 0.1, accuracy: 1e-9)
        XCTAssertEqual(m.squareRadius, m.bit * 0.12, accuracy: 1e-9)
        XCTAssertEqual(m.decimalTimeSize, min(m.bit * 0.62, 2.4 * m.fontSize), accuracy: 1e-9)
        XCTAssertEqual(m.decimalDateSize, min(m.bit * 0.4, 1.6 * m.fontSize), accuracy: 1e-9)
        XCTAssertEqual(m.placeSize, min(15, max(9, m.bit * 0.2)), accuracy: 1e-9)
        XCTAssertEqual(m.readoutSize, 1.5 * m.fontSize, accuracy: 1e-9)
        XCTAssertEqual(m.separatorMargin, m.gap * 1.2, accuracy: 1e-9)
        XCTAssertEqual(m.dateRowGap, m.gap * 0.6, accuracy: 1e-9)
        XCTAssertEqual(m.chromeGap, 24)
        XCTAssertEqual(m.bitBlockWidth, 172.8 + 11 * m.bit + 12 * 12.6 + 129.6, accuracy: 1e-9)
        XCTAssertLessThan(m.bitBlockWidth, 1440 - 2 * m.pad)
    }

    func testNarrowPhoneLikeScreen() throws {
        let m = try LayoutMetrics.compute(width: 390, height: 844, columns: 11, tokens: tokens)
        XCTAssertTrue(m.isNarrow)
        XCTAssertEqual(m.pad, 4.2 * 3.9, accuracy: 1e-9)
        XCTAssertEqual(m.gap, 6, "Clamped to the 6 px floor")
        // (390 − 2·16.38 − 10·6) / 11 ≈ 27.0 pt — width-limited.
        XCTAssertEqual(m.bit, (390 - 2 * 16.38 - 60) / 11, accuracy: 1e-9)
        XCTAssertEqual(m.decimalTimeSize, 1.3 * m.fontSize, accuracy: 1e-9)
        XCTAssertEqual(m.readoutSize, 1.15 * m.fontSize, accuracy: 1e-9)
        XCTAssertEqual(m.separatorMargin, m.gap * 0.6, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(m.gridWidth, 390 - 2 * m.pad)
    }

    func testBreakpointBoundary() throws {
        XCTAssertTrue(try LayoutMetrics.compute(width: 680, height: 900, columns: 11, tokens: tokens).isNarrow)
        XCTAssertFalse(try LayoutMetrics.compute(width: 681, height: 900, columns: 11, tokens: tokens).isNarrow)
        XCTAssertFalse(try LayoutMetrics.compute(width: 680, height: 900, columns: 11, tokens: tokens, isNarrow: false).isNarrow)
    }

    func testUltrawideIsHeightLimitedAndCapped() throws {
        let m = try LayoutMetrics.compute(width: 3440, height: 1440, columns: 11, tokens: tokens)
        XCTAssertEqual(m.pad, 60.48, accuracy: 1e-9)
        XCTAssertEqual(m.bit, (1440 - 2 * 60.48 - 432) / 10.4, accuracy: 1e-9)
        let huge = try LayoutMetrics.compute(width: 7680, height: 4320, columns: 11, tokens: tokens)
        XCTAssertEqual(huge.bit, 116, "Capped at 116 px")
        XCTAssertEqual(huge.pad, 64)
        XCTAssertEqual(huge.fontSize, 22)
    }

    func testPortraitStaysWithinBounds() throws {
        let m = try LayoutMetrics.compute(width: 900, height: 1600, columns: 11, tokens: tokens)
        XCTAssertFalse(m.isNarrow)
        XCTAssertLessThanOrEqual(m.bitBlockWidth, 900 - 2 * m.pad + 1e-9)
    }

    func testBlockFitsForEveryCalendarWidth() throws {
        for columns in [11, 12, 13, 14] {
            for (w, h) in [(1440.0, 900.0), (1920.0, 1080.0), (2560.0, 1600.0), (3440.0, 1440.0), (900.0, 1600.0), (1024.0, 768.0), (800.0, 600.0)] {
                let m = try LayoutMetrics.compute(width: w, height: h, columns: columns, tokens: tokens)
                XCTAssertLessThanOrEqual(m.bitBlockWidth, w - 2 * m.pad + 1e-9, "\(w)×\(h) w=\(columns)")
                XCTAssertGreaterThan(m.bit, 4, "\(w)×\(h) w=\(columns)")
            }
        }
    }

    func testCellOffsets() throws {
        let m = try LayoutMetrics.compute(width: 1440, height: 900, columns: 11, tokens: tokens)
        XCTAssertEqual(m.cellOffsetX(column: 0, size: m.bit), 0)
        XCTAssertEqual(m.cellOffsetX(column: 1, size: m.bit), m.bit + m.gap, accuracy: 1e-9)
        XCTAssertEqual(m.cellOffsetX(column: 0, size: m.dateBit), (m.bit - m.dateBit) / 2, accuracy: 1e-9)
        XCTAssertEqual(m.gridWidth, 11 * m.bit + 10 * m.gap, accuracy: 1e-9)
    }
}
