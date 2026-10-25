import AppKit
import XCTest
import BinaryTimeCore
@testable import BinaryTimeUI

/// The view follows window resizes: the root layer tracks the bounds and the content is laid out again.
final class ClockSceneViewTests: XCTestCase {
    private func makeView(_ size: NSSize) -> (NSWindow, ClockSceneView) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        let view = ClockSceneView(resources: SceneLayoutTests.resources, settings: .default, frame: NSRect(origin: .zero, size: size))
        view.autoresizingMask = [.width, .height]
        view.monitorsVPN = false
        view.clock = { SceneLayoutTests.instant }
        view.composer.timeZone = SceneLayoutTests.moscow
        window.contentView = view
        view.renderNow()
        return (window, view)
    }

    func testRootLayerAndSceneFollowResize() {
        let (window, view) = makeView(NSSize(width: 1440, height: 900))
        XCTAssertEqual(view.scene.size, CGSize(width: 1440, height: 900))
        XCTAssertEqual(view.scene.rootLayer.frame, CGRect(x: 0, y: 0, width: 1440, height: 900))
        XCTAssertFalse(view.scene.frames!.isNarrow)

        window.setContentSize(NSSize(width: 900, height: 1600))
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.bounds.size, CGSize(width: 900, height: 1600))
        XCTAssertEqual(view.scene.size, CGSize(width: 900, height: 1600), "scene must be re-laid out on resize")
        XCTAssertEqual(view.scene.rootLayer.frame, CGRect(x: 0, y: 0, width: 900, height: 1600))
        let readout = view.scene.frames!.texts[.readout]!.frame
        XCTAssertLessThan(readout.maxY, 1600)
        XCTAssertGreaterThan(readout.minY, 1400, "readout sits in the footer of the new height")

        window.setContentSize(NSSize(width: 390, height: 844))
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.scene.frames!.isNarrow, "narrow layout below the breakpoint")
        XCTAssertEqual(view.scene.miniatureScale, 1)

        window.setContentSize(NSSize(width: 300, height: 190))
        view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.scene.miniatureScale, 1, "tiny sizes draw a miniature")
        XCTAssertEqual(view.scene.rootLayer.frame.size, CGSize(width: 300, height: 190))
    }

    func testSnapshotFollowsSize() {
        let (window, view) = makeView(NSSize(width: 800, height: 600))
        window.setContentSize(NSSize(width: 640, height: 480))
        view.layoutSubtreeIfNeeded()
        let image = view.snapshot(scale: 1)
        XCTAssertEqual(image?.width, 640)
        XCTAssertEqual(image?.height, 480)
    }

    func testSceneHasNoForeignSublayersAndRebuildKeepsCount() {
        let (_, view) = makeView(NSSize(width: 1440, height: 900))
        let before = view.scene.rootLayer.sublayers?.count ?? 0
        XCTAssertGreaterThan(before, 7 * 11, "bits plus texts")
        var s = view.settings
        s.language = .fixed(.he)
        s.calendar = .hebrew
        view.settings = s  // 13 columns: structure rebuilt
        let after = view.scene.rootLayer.sublayers?.count ?? 0
        XCTAssertGreaterThan(after, before, "13-column grid has more bit layers")
        XCTAssertEqual(view.scene.model?.language, .he)
    }

    func testThemeChangeRestylesControls() {
        final class Host: NSView, ControlsSizing {
            var themes: [Theme] = []
            func preferredSize(forWidth width: CGFloat, metrics: LayoutMetrics, model: ScreenModel) -> CGSize {
                themes.append(model.theme)
                return CGSize(width: 500, height: 44)
            }
        }
        let (_, view) = makeView(NSSize(width: 1440, height: 900))
        let host = Host(frame: .zero)
        view.controlsHost = host
        XCTAssertEqual(host.themes.last, .dark)
        var s = view.settings
        s.theme = .light
        view.settings = s
        XCTAssertEqual(host.themes.last, .light, "controls must be restyled when the theme flips")
    }

    func testControlsFrameIsPublished() {
        final class Host: NSView, ControlsSizing {
            func preferredSize(forWidth width: CGFloat, metrics: LayoutMetrics, model: ScreenModel) -> CGSize { CGSize(width: 500, height: 44) }
        }
        let (window, view) = makeView(NSSize(width: 1440, height: 900))
        var published: [NSRect] = []
        view.onControlsFrameChange = { published.append($0) }
        let host = Host(frame: .zero)
        view.controlsHost = host
        XCTAssertEqual(published.last?.size, CGSize(width: 500, height: 44))
        XCTAssertEqual(published.last!.minY, 37.8, accuracy: 0.01, "bottom padding")
        XCTAssertEqual(published.last!.maxX, 1440 - 37.8, accuracy: 0.01, "right padding (LTR)")
        var s = view.settings
        s.showControls = false
        view.settings = s
        XCTAssertEqual(published.last, .zero, "hidden controls publish an empty frame")
        window.setContentSize(NSSize(width: 1200, height: 800))
        view.layoutSubtreeIfNeeded()
        s.showControls = true
        view.settings = s
        XCTAssertEqual(published.last!.maxX, 1200 - published.last!.minY, accuracy: 0.01)
    }
}
