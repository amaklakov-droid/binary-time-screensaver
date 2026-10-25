import AppKit
import XCTest
import BinaryTimeCore
@testable import BinaryTimeUI

/// Geometry checks for every reference case and a sweep of sizes: nothing clips, nothing overlaps.
final class SceneLayoutTests: XCTestCase {
    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }()
    static let resources = try! AppResources(repositoryRoot: repoRoot)
    static let instant = ISO8601DateFormatter().date(from: "2026-10-24T16:59:17Z")!
    static let moscow = TimeZone(identifier: "Europe/Moscow")!

    struct Case {
        var name: String
        var size: CGSize
        var language: Language
        var calendar: CalendarSetting = .auto
        var hourFormat: HourFormat = .h24
        var theme: Theme = .dark
        var shape: BitShape = .dot
        var location: LocationMode = .auto
        var controls = false
    }

    static let referenceCases: [Case] = [
        Case(name: "01", size: CGSize(width: 1440, height: 900), language: .en),
        Case(name: "02", size: CGSize(width: 1440, height: 900), language: .ru),
        Case(name: "03", size: CGSize(width: 1440, height: 900), language: .ru, hourFormat: .h12, theme: .light, shape: .square),
        Case(name: "04", size: CGSize(width: 1440, height: 900), language: .he, calendar: .hebrew),
        Case(name: "05", size: CGSize(width: 1440, height: 900), language: .ar, calendar: .islamic, hourFormat: .h12, theme: .light),
        Case(name: "06", size: CGSize(width: 1440, height: 900), language: .bo, calendar: .buddhist),
        Case(name: "07", size: CGSize(width: 1440, height: 900), language: .ja, location: .vpn),
        Case(name: "08", size: CGSize(width: 3440, height: 1440), language: .ru),
        Case(name: "09", size: CGSize(width: 900, height: 1600), language: .ru),
        Case(name: "10", size: CGSize(width: 390, height: 844), language: .ja, location: .vpn),
        Case(name: "11", size: CGSize(width: 1440, height: 900), language: .ru, controls: true),
    ]

    private func model(for c: Case) -> ScreenModel {
        var settings = Settings.default
        settings.language = .fixed(c.language)
        settings.calendar = c.calendar
        settings.hourFormat = c.hourFormat
        settings.theme = c.theme
        settings.bitShape = c.shape
        settings.location = c.location
        settings.showControls = c.controls
        let composer = FrameComposer(resources: Self.resources.core, settings: settings, timeZone: Self.moscow,
                                     preferredLanguages: ["en"], osCalendar: .gregorian,
                                     spaceRotator: SpaceRotator(count: Self.resources.core.catalog.objects.count, period: 20, epoch: Self.instant, startIndex: 13),
                                     now: Self.instant)
        return composer.frame(at: Self.instant)
    }

    private func frames(for c: Case, size: CGSize? = nil) throws -> (SceneFrames, LayoutMetrics, ScreenModel) {
        let m = model(for: c)
        let sz = size ?? c.size
        let fitted = try SceneLayout.fit(model: m, tokens: Self.resources.core.tokens, fonts: Self.resources.fonts, size: sz,
                                         controlsSize: { width, _ in c.controls ? CGSize(width: min(width, 620), height: 44) : nil })
        return (fitted.frames, fitted.metrics, m)
    }

    func testReferenceCasesLayOutNatively() throws {
        for c in Self.referenceCases {
            let m = model(for: c)
            let fitted = try SceneLayout.fit(model: m, tokens: Self.resources.core.tokens, fonts: Self.resources.fonts, size: c.size,
                                             controlsSize: { width, _ in c.controls ? CGSize(width: min(width, 620), height: 44) : nil })
            XCTAssertEqual(fitted.scale, 1, "\(c.name) must not need the miniature fallback")
        }
    }

    func testTinyPreviewFallsBackToMiniature() throws {
        let m = model(for: Self.referenceCases[0])
        let fitted = try SceneLayout.fit(model: m, tokens: Self.resources.core.tokens, fonts: Self.resources.fonts, size: CGSize(width: 300, height: 190), controlsSize: { _, _ in nil })
        XCTAssertEqual(fitted.scale, 900 / 190, accuracy: 1e-9)
        XCTAssertEqual(fitted.virtualSize.height, 900, accuracy: 1e-9)
        XCTAssertFalse(fitted.frames.overflows)
    }

    private func assertSane(_ frames: SceneFrames, _ metrics: LayoutMetrics, _ m: ScreenModel, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let bounds = CGRect(origin: .zero, size: frames.size).insetBy(dx: -0.5, dy: -0.5)
        XCTAssertFalse(frames.overflows, "\(label): bit block taller than the available space", file: file, line: line)
        for (element, placement) in frames.texts {
            XCTAssertTrue(bounds.contains(placement.frame), "\(label): \(element) text frame \(placement.frame) leaves the screen", file: file, line: line)
            XCTAssertGreaterThan(placement.frame.height, 0, "\(label): \(element) has no height", file: file, line: line)
        }
        for (element, rect) in frames.shapes {
            XCTAssertTrue(bounds.contains(rect), "\(label): \(element) shape \(rect) leaves the screen", file: file, line: line)
        }
        // Bits in one row are disjoint and ordered left to right.
        for metric in Metric.allCases {
            let cells = (0..<m.columns).compactMap { frames.shapes[.bit(metric, $0)] }
            XCTAssertEqual(cells.count, m.columns, "\(label): \(metric) has \(cells.count) cells", file: file, line: line)
            for (a, b) in zip(cells, cells.dropFirst()) {
                XCTAssertLessThanOrEqual(a.maxX, b.minX + 0.01, "\(label): \(metric) cells overlap", file: file, line: line)
                XCTAssertEqual(a.midY, b.midY, accuracy: 0.01, "\(label): \(metric) cells not on one line", file: file, line: line)
            }
        }
        // Rows are stacked without overlap: hours grid below day grid, hundredths above the footer readout.
        let dayBits = frames.shapes[.bit(.day, 0)]!, hourBits = frames.shapes[.bit(.hours, 0)]!, lastBits = frames.shapes[.bit(.hundredths, 0)]!
        XCTAssertLessThan(dayBits.maxY, hourBits.minY, "\(label): date and time groups overlap", file: file, line: line)
        XCTAssertLessThan(lastBits.maxY, frames.texts[.readout]!.frame.minY, "\(label): bit block overlaps the readout", file: file, line: line)
        let header = max(frames.texts[.dateLine]!.frame.maxY, frames.texts[.locationL2]!.frame.maxY)
        let firstRow = min(frames.texts[.rowLabel(.year)]!.frame.minY, frames.shapes[.bit(.year, 0)]!.minY, frames.texts[.placeLabel]?.frame.minY ?? .infinity)
        XCTAssertLessThan(header, firstRow, "\(label): header overlaps the bit block", file: file, line: line)
        // The grid is LTR in every language: the most significant column is leftmost.
        XCTAssertLessThan(frames.shapes[.bit(.year, 0)]!.minX, frames.shapes[.bit(.year, m.columns - 1)]!.minX, "\(label): grid not LTR", file: file, line: line)
        if m.direction == .rtl && !frames.isNarrow {
            XCTAssertLessThan(frames.texts[.rowDecimal(.hours)]!.frame.minX, frames.shapes[.bit(.hours, 0)]!.minX, "\(label): RTL decimals must sit left of the grid", file: file, line: line)
            XCTAssertGreaterThan(frames.texts[.rowLabel(.hours)]!.frame.minX, frames.shapes[.bit(.hours, m.columns - 1)]!.maxX, "\(label): RTL labels must sit right of the grid", file: file, line: line)
        }
        if frames.isNarrow {
            XCTAssertNil(frames.texts[.placeLabel], "\(label): place values hidden on narrow screens", file: file, line: line)
        }
    }

    func testReferenceCasesFitWithoutOverlap() throws {
        for c in Self.referenceCases {
            let (frames, metrics, m) = try frames(for: c)
            assertSane(frames, metrics, m, c.name)
        }
    }

    func testSizeSweepForEveryLanguage() throws {
        let sizes: [CGSize] = [CGSize(width: 320, height: 240), CGSize(width: 480, height: 800), CGSize(width: 680, height: 1000),
                               CGSize(width: 681, height: 500), CGSize(width: 800, height: 600), CGSize(width: 1024, height: 768),
                               CGSize(width: 1280, height: 720), CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1440),
                               CGSize(width: 5120, height: 2160), CGSize(width: 1080, height: 1920)]
        for lang in Language.allCases {
            for cal in CalendarSetting.allCases {
                let c = Case(name: "\(lang)-\(cal)", size: .zero, language: lang, calendar: cal)
                for size in sizes {
                    let (frames, metrics, m) = try frames(for: c, size: size)
                    assertSane(frames, metrics, m, "\(c.name) \(Int(size.width))×\(Int(size.height))")
                }
            }
        }
    }

    func testControlsReserveFooterSpace() throws {
        let (wide, _, _) = try frames(for: Self.referenceCases[10])
        XCTAssertFalse(wide.controls.isEmpty)
        XCTAssertGreaterThan(wide.controls.minX, wide.texts[.readout]!.frame.maxX, "Wide: controls sit right of the readout")
        var narrow = Self.referenceCases[9]
        narrow.controls = true
        let (n, _, _) = try frames(for: narrow)
        XCTAssertGreaterThan(n.controls.minY, n.texts[.legendOffset]!.frame.maxY, "Narrow: controls wrap below the legend")
        XCTAssertLessThan(n.shapes[.bit(.hundredths, 0)]!.maxY, n.texts[.readout]!.frame.minY)
    }

    func testPlaintextDirection() {
        XCTAssertEqual(SceneLayout.plaintextDirection(of: "Moscow · רוסיה"), .ltr)
        XCTAssertEqual(SceneLayout.plaintextDirection(of: "רוסיה · Moscow"), .rtl)
        XCTAssertEqual(SceneLayout.plaintextDirection(of: "هجري · أم القرى · تلقائي"), .rtl)
        XCTAssertEqual(SceneLayout.plaintextDirection(of: "2026·10·24  19:59:17.80"), .ltr)
        XCTAssertEqual(SceneLayout.plaintextDirection(of: "RA 05h35m17s · Dec −05°23′28″"), .ltr)
        XCTAssertEqual(SceneLayout.plaintextDirection(of: "ལོ་༢༥༦༩ ཟླ་༡༠"), .ltr)
        let he = model(for: Self.referenceCases[3])
        XCTAssertEqual(SceneLayout.direction(of: .readout, in: he), .ltr)
        XCTAssertEqual(SceneLayout.direction(of: .legendOffset, in: he), .ltr)
        XCTAssertEqual(SceneLayout.direction(of: .rowSub(.hours), in: he), .rtl)
        XCTAssertEqual(SceneLayout.direction(of: .locationL1, in: he), .ltr, "«Moscow · רוסיה» starts with Latin")
        XCTAssertEqual(SceneLayout.direction(of: .dateLine, in: he), .rtl)
    }

    func testMetricsMatchTokensForReferenceScreen() throws {
        let (frames, metrics, _) = try frames(for: Self.referenceCases[0])
        XCTAssertEqual(frames.bitSize[.hours]!, CGFloat(metrics.bit), accuracy: 0.001)
        XCTAssertEqual(frames.bitSize[.year]!, CGFloat(metrics.dateBit), accuracy: 0.001)
        let gridLeft = frames.shapes[.bit(.hours, 0)]!.minX
        let gridRight = frames.shapes[.bit(.hours, 10)]!.maxX
        XCTAssertEqual(gridRight - gridLeft, CGFloat(metrics.gridWidth), accuracy: 0.01)
        // The block is centred horizontally.
        let blockLeft = frames.texts[.rowLabel(.hours)]!.frame.minX
        let blockRight = frames.texts[.rowDecimal(.hours)]!.frame.maxX
        XCTAssertEqual(blockLeft, frames.size.width - blockRight, accuracy: 0.5)
    }

    func testGlyphLayerDrawsSomething() {
        let layer = GlyphLayer()
        layer.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        layer.textStyle = TextStyle(font: Self.resources.fonts.font(weight: 600, size: 20), trackingEm: 0.1, uppercase: true, opacity: 1, lineHeightMultiple: nil)
        layer.text = "Binary"
        layer.fgColor = CGColor(gray: 1, alpha: 1)
        let context = CGContext(data: nil, width: 200, height: 40, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        layer.draw(in: context)
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        let painted = (0..<(context.bytesPerRow * 40)).contains { data[$0] != 0 }
        XCTAssertTrue(painted, "Core Text drew no pixels")
    }
}
