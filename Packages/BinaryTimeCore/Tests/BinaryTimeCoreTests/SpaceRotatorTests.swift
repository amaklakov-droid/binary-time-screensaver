import Foundation
import XCTest
@testable import BinaryTimeCore

final class SpaceRotatorTests: XCTestCase {
    let epoch = Fixtures.referenceInstant

    func testRotatesEveryTwentySeconds() {
        let rotator = SpaceRotator(count: 17, period: 20, epoch: epoch, startIndex: 15)
        XCTAssertEqual(rotator.index(at: epoch), 15)
        XCTAssertEqual(rotator.index(at: epoch.addingTimeInterval(19.99)), 15)
        XCTAssertEqual(rotator.index(at: epoch.addingTimeInterval(20)), 16)
        XCTAssertEqual(rotator.index(at: epoch.addingTimeInterval(40)), 0, "Wraps around the catalog")
        XCTAssertEqual(rotator.index(at: epoch.addingTimeInterval(-5)), 15, "Time before the epoch is clamped")
    }

    func testUsesCatalogPeriodAndRandomStart() {
        var g1 = SeededGenerator(seed: 42)
        var g2 = SeededGenerator(seed: 42)
        let a = SpaceRotator(catalog: Fixtures.catalog, now: epoch, using: &g1)
        let b = SpaceRotator(catalog: Fixtures.catalog, now: epoch, using: &g2)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.period, Fixtures.catalog.rotateEverySeconds)
        XCTAssertEqual(a.period, 20)
        XCTAssertEqual(a.count, Fixtures.catalog.objects.count)
        XCTAssertTrue((0..<a.count).contains(a.startIndex))
    }

    func testStartIndicesSpreadAcrossCatalog() {
        var seen = Set<Int>()
        for seed in 0..<200 {
            var g = SeededGenerator(seed: UInt64(seed))
            seen.insert(SpaceRotator(catalog: Fixtures.catalog, now: epoch, using: &g).startIndex)
        }
        XCTAssertGreaterThan(seen.count, 10)
    }

    func testAdvanceSkipsToNext() {
        var rotator = SpaceRotator(count: 3, period: 20, epoch: epoch, startIndex: 2)
        rotator.advance()
        XCTAssertEqual(rotator.index(at: epoch), 0)
    }

    func testDegenerateInputsAreSafe() {
        let rotator = SpaceRotator(count: 0, period: 0, epoch: epoch, startIndex: -7)
        XCTAssertEqual(rotator.count, 1)
        XCTAssertEqual(rotator.index(at: epoch.addingTimeInterval(1000)), 0)
    }
}
