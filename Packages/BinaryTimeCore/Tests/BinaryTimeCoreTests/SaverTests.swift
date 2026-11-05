import Foundation
import XCTest
@testable import BinaryTimeCore

final class SaverLifecycleTests: XCTestCase {
    func testSmallViewIsPreviewEvenIfHostSaysOtherwise() {
        XCTAssertTrue(SaverLifecycle.isPreview(reported: false, width: 296, height: 184))
        XCTAssertTrue(SaverLifecycle.isPreview(reported: false, width: 1440, height: 399))
        XCTAssertFalse(SaverLifecycle.isPreview(reported: false, width: 1440, height: 900))
        XCTAssertTrue(SaverLifecycle.isPreview(reported: true, width: 1440, height: 900))
        // Before the first layout the frame can be empty; trust the host then.
        XCTAssertFalse(SaverLifecycle.isPreview(reported: false, width: 0, height: 0))
    }

    func testPreviewSurvivesWillStop() {
        XCTAssertFalse(SaverLifecycle.exitsOnWillStop(isPreview: true))
        XCTAssertTrue(SaverLifecycle.exitsOnWillStop(isPreview: false))
    }
}

final class EngineWatchTests: XCTestCase {
    func testOnlyADisappearanceCounts() {
        var watch = EngineWatch()
        XCTAssertFalse(watch.update(engineRunning: false), "a preview never sees the engine")
        XCTAssertFalse(watch.update(engineRunning: false))
        XCTAssertFalse(watch.update(engineRunning: true))
        XCTAssertFalse(watch.update(engineRunning: true))
        XCTAssertFalse(watch.update(engineRunning: false))
        XCTAssertFalse(watch.update(engineRunning: false))
        XCTAssertTrue(watch.update(engineRunning: false))
    }

    /// One empty answer from the running-app list must not quit a saver whose engine still runs.
    func testShortMissesAreIgnored() {
        var watch = EngineWatch()
        XCTAssertFalse(watch.update(engineRunning: true))
        for _ in 0..<10 {
            XCTAssertFalse(watch.update(engineRunning: false))
            XCTAssertFalse(watch.update(engineRunning: false))
            XCTAssertFalse(watch.update(engineRunning: true))
        }
        XCTAssertEqual(EngineWatch.missesToStop, 3)
    }
}

final class SaverInstanceRegistryTests: XCTestCase {
    let main = SaverSlot(screen: "1", isPreview: false)
    let side = SaverSlot(screen: "2", isPreview: false)
    let preview = SaverSlot(screen: "1", isPreview: true)

    func testNewestInstanceOnAScreenReplacesTheOld() {
        var r = SaverInstanceRegistry<Int>()
        XCTAssertNil(r.activate(1, in: main))
        XCTAssertEqual(r.activate(2, in: main), 1)
        XCTAssertFalse(r.isLive(1))
        XCTAssertTrue(r.isLive(2))
        XCTAssertEqual(r.liveCount, 1)
    }

    func testScreensAndPreviewsAreIndependent() {
        var r = SaverInstanceRegistry<Int>()
        XCTAssertNil(r.activate(1, in: main))
        XCTAssertNil(r.activate(2, in: side))
        XCTAssertNil(r.activate(3, in: preview))
        XCTAssertEqual(r.liveCount, 3)
    }

    func testReactivationAndMovesDoNotDuplicate() {
        var r = SaverInstanceRegistry<Int>()
        _ = r.activate(1, in: main)
        XCTAssertNil(r.activate(1, in: main))
        XCTAssertNil(r.activate(1, in: side))
        XCTAssertEqual(r.liveCount, 1)
        r.deactivate(1)
        XCTAssertEqual(r.liveCount, 0)
        XCTAssertNil(r.activate(2, in: main))
    }

    /// Twenty activate/dismiss cycles without teardown leave one live instance per screen (MACOS.md §5).
    func testTwentyCyclesKeepOneInstancePerScreen() {
        var r = SaverInstanceRegistry<Int>()
        for cycle in 0..<20 {
            _ = r.activate(cycle * 2, in: main)
            _ = r.activate(cycle * 2 + 1, in: side)
        }
        XCTAssertEqual(r.liveCount, 2)
        XCTAssertTrue(r.isLive(38))
        XCTAssertTrue(r.isLive(39))
    }
}

final class SettingsStoreTests: XCTestCase {
    /// In memory, so tests leave nothing in the user's preferences.
    final class MemoryStorage: SettingsStorage {
        var values: [String: Any] = [:]
        var syncs = 0
        func object(forKey key: String) -> Any? { values[key] }
        func set(_ value: Any?, forKey key: String) { values[key] = value }
        func synchronize() -> Bool { syncs += 1; return true }
    }

    private var defaults: MemoryStorage!

    override func setUp() {
        defaults = MemoryStorage()
    }

    func testEmptyStoreGivesDefaults() {
        XCTAssertEqual(SettingsStore(storage: defaults).load(), .default)
    }

    func testUserDefaultsIsAStorage() {
        let storage: SettingsStorage = UserDefaults.standard
        XCTAssertNotNil(storage)
    }

    func testSaveAndLoadRoundTrip() {
        var s = Settings()
        s.language = .fixed(.bo)
        s.hourFormat = .h12
        s.calendar = .hebrew
        s.theme = .light
        s.bitShape = .square
        s.location = .vpn
        SettingsStore(storage: defaults).save(s)
        XCTAssertEqual(SettingsStore(storage: defaults).load(), s)
        XCTAssertEqual(defaults.values["lang"] as? String, "bo")
        XCTAssertEqual(defaults.syncs, 1)
    }

    func testForeignKeysAreIgnored() {
        defaults.set("x", forKey: "unrelated")
        defaults.set("islamic", forKey: "calendar")
        XCTAssertEqual(SettingsStore(storage: defaults).load().calendar, .islamic)
    }
}

final class OptionsSheetModelTests: XCTestCase {
    func model(_ s: Settings = .default, preferred: [String] = ["en-US"]) -> OptionsSheetModel {
        OptionsSheetModel(settings: s, catalog: Fixtures.i18n, preferredLanguages: preferred)
    }

    func testRowsCoverSpecSettingsExceptOnlineCheck() {
        XCTAssertEqual(model().rows.map(\.field), OptionsSheetModel.Field.allCases)
        XCTAssertEqual(model().rows.map(\.field), [.language, .hourFormat, .calendar, .theme, .bitShape, .location])
    }

    func testEveryLanguageHasAllLabels() {
        for lang in Language.allCases {
            var s = Settings()
            s.language = .fixed(lang)
            let m = model(s)
            XCTAssertEqual(m.language, lang)
            XCTAssertFalse(m.title.isEmpty, "\(lang)")
            XCTAssertFalse(m.done.isEmpty, "\(lang)")
            XCTAssertFalse(m.cancel.isEmpty, "\(lang)")
            for row in m.rows {
                XCTAssertFalse(row.title.isEmpty, "\(lang) \(row.field)")
                XCTAssertTrue(row.choices.allSatisfy { !$0.label.isEmpty }, "\(lang) \(row.field)")
            }
        }
    }

    func testChoicesAndSelectionFollowSettings() {
        var s = Settings()
        s.language = .fixed(.ru)
        s.calendar = .hebrew
        s.hourFormat = .h12
        s.bitShape = .square
        let m = model(s)
        let rows = Dictionary(uniqueKeysWithValues: m.rows.map { ($0.field, $0) })
        XCTAssertEqual(rows[.language]!.choices.map(\.value), ["auto", "en", "ru", "he", "ar", "bo", "ja"])
        XCTAssertEqual(rows[.language]!.choices[0].label, "Авто")
        XCTAssertEqual(rows[.language]!.choices[2].label, "Русский")
        XCTAssertEqual(rows[.language]!.selectedIndex, 2)
        XCTAssertEqual(rows[.calendar]!.choices.map(\.value), ["auto", "gregory", "islamic", "hebrew", "buddhist"])
        XCTAssertEqual(rows[.calendar]!.selectedIndex, 3)
        XCTAssertEqual(rows[.hourFormat]!.choices.map(\.value), ["24", "12"])
        XCTAssertEqual(rows[.hourFormat]!.selectedIndex, 1)
        XCTAssertEqual(rows[.bitShape]!.choices[rows[.bitShape]!.selectedIndex].label, "Квадрат")
        XCTAssertEqual(rows[.location]!.choices.map(\.value), ["auto", "vpn"])
    }

    func testAutoLanguageUsesSystemLanguageAndDirection() {
        let m = model(preferred: ["he-IL"])
        XCTAssertEqual(m.language, .he)
        XCTAssertEqual(m.direction, .rtl)
        XCTAssertEqual(m.rows[0].selectedIndex, 0)
    }

    func testArabicDigitsInLabels() {
        var s = Settings()
        s.language = .fixed(.ar)
        let hours = model(s).rows.first { $0.field == .hourFormat }!
        XCTAssertTrue(hours.choices[0].label.contains("٢٤"), hours.choices[0].label)
        XCTAssertFalse(hours.choices[0].label.contains("24"))
    }

    func testApplyingChoices() {
        var s = Settings.default
        for row in model().rows {
            s = OptionsSheetModel.applying(row.choices.last!.value, to: row.field, in: s)
        }
        XCTAssertEqual(s.language, .fixed(.ja))
        XCTAssertEqual(s.hourFormat, .h12)
        XCTAssertEqual(s.calendar, .buddhist)
        XCTAssertEqual(s.theme, .light)
        XCTAssertEqual(s.bitShape, .square)
        XCTAssertEqual(s.location, .vpn)
        XCTAssertEqual(OptionsSheetModel.applying("persian", to: .calendar, in: s), s)
        XCTAssertEqual(OptionsSheetModel.applying("auto", to: .language, in: s).language, .auto)
    }
}
