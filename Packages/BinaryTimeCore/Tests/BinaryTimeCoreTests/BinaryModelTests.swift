import Foundation
import XCTest
@testable import BinaryTimeCore

final class BinaryModelTests: XCTestCase {
    func testBitLengthMatchesSpecExamples() {
        XCTAssertEqual(BinaryModel.bitLength(2026), 11)   // Gregorian
        XCTAssertEqual(BinaryModel.bitLength(5787), 13)   // Hebrew
        XCTAssertEqual(BinaryModel.bitLength(2569), 12)   // Buddhist
        XCTAssertEqual(BinaryModel.bitLength(1448), 11)   // Islamic
        XCTAssertEqual(BinaryModel.bitLength(1), 1)
        XCTAssertEqual(BinaryModel.bitLength(0), 1)
        XCTAssertEqual(BinaryModel.bitLength(2047), 11)
        XCTAssertEqual(BinaryModel.bitLength(2048), 12)
    }

    func testColumnsClampBetween7And14() {
        XCTAssertEqual(BinaryModel.columns(forYear: 2026), 11)
        XCTAssertEqual(BinaryModel.columns(forYear: 5787), 13)
        XCTAssertEqual(BinaryModel.columns(forYear: 5), 7)
        XCTAssertEqual(BinaryModel.columns(forYear: 1 << 20), 14)
    }

    func testPlaceValuesMostSignificantFirst() {
        XCTAssertEqual(BinaryModel.placeValues(columns: 11), [1024, 512, 256, 128, 64, 32, 16, 8, 4, 2, 1])
        XCTAssertEqual(BinaryModel.placeValues(columns: 13).first, 4096)
    }

    func testStatesRightAlignedWithVoidPadding() {
        // 12 in 12 h mode: 4 bits → 1100, seven void positions on the left in an 11-column grid.
        let states = BinaryModel.states(value: 12, bits: 4, columns: 11)
        XCTAssertEqual(states.count, 11)
        XCTAssertEqual(Array(states.prefix(7)), Array(repeating: BitState.void, count: 7))
        XCTAssertEqual(Array(states.suffix(4)), [.on, .on, .off, .off])
    }

    func testStatesForReferenceYear() {
        // 2026 = 11111101010
        let states = BinaryModel.states(value: 2026, bits: 11, columns: 11)
        let expected: [BitState] = "11111101010".map { $0 == "1" ? .on : .off }
        XCTAssertEqual(states, expected)
    }

    func testHundredthsEdges() {
        XCTAssertEqual(BinaryModel.states(value: 0, bits: 7, columns: 7), Array(repeating: .off, count: 7))
        XCTAssertEqual(BinaryModel.binaryString(99, bits: 7), "1100011")
        XCTAssertEqual(BinaryModel.states(value: 99, bits: 7, columns: 7), "1100011".map { $0 == "1" ? .on : .off })
    }

    func testBinaryStringPads() {
        XCTAssertEqual(BinaryModel.binaryString(12, bits: 4), "1100")
        XCTAssertEqual(BinaryModel.binaryString(5, bits: 5), "00101")
        XCTAssertEqual(BinaryModel.binaryString(0, bits: 6), "000000")
    }
}
