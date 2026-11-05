import AppKit
import ScreenSaver
import os
import BinaryTimeCore
import BinaryTimeUI

/// The `.saver` principal class: hosts a `ClockSceneView` and applies the lifecycle workarounds
/// from MACOS.md §2. The rules live in `SaverLifecycle` / `SaverInstanceRegistry` (Core, tested).
/// The Objective-C name is explicit and prefixed: every legacy saver shares one host process.
@objc(BinaryTimeSaverView)
final class BinaryTimeSaverView: ScreenSaverView {
    static let settingsDidChange = Notification.Name("BinaryTimeSettingsDidChange")

    private static let log = Logger(subsystem: bundle.bundleIdentifier ?? "BinaryTime", category: "saver")
    static let bundle = Bundle(for: BinaryTimeSaverView.self)

    /// Decoded data and registered fonts, shared by every instance in the host process.
    static let resources: AppResources? = {
        do {
            return try AppResources(bundle: bundle)
        } catch {
            log.error("Cannot load resources: \(String(describing: error), privacy: .public)")
            return nil
        }
    }()

    static var store: SettingsStore? {
        guard let id = bundle.bundleIdentifier, let defaults = ScreenSaverDefaults(forModuleWithName: id) else { return nil }
        return SettingsStore(storage: defaults)
    }

    private static var registry = SaverInstanceRegistry<ObjectIdentifier>()
    private static let instances = NSHashTable<BinaryTimeSaverView>.weakObjects()

    private var sceneView: ClockSceneView?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var sheet: OptionsSheet?
    private let reportedPreview: Bool
    private var engineWatch = EngineWatch()
    private var engineTimer: Timer?

    override init?(frame: NSRect, isPreview: Bool) {
        reportedPreview = isPreview
        super.init(frame: frame, isPreview: isPreview)
        // The scene's own once-a-second timer drives frames (MACOS.md §2.3); keep the framework timer idle.
        animationTimeInterval = 1
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        if let resources = Self.resources {
            let view = ClockSceneView(resources: resources, settings: Self.store?.load() ?? .default, frame: bounds)
            view.autoresizingMask = [.width, .height]
            addSubview(view)
            sceneView = view
        }
        Self.instances.add(self)

        let local = NotificationCenter.default
        observers.append((local, local.addObserver(forName: Self.settingsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadSettings()
        }))
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(
            forName: Notification.Name(SaverLifecycle.willStopNotification), object: nil, queue: .main) { [weak self] _ in
                self?.screenSaverWillStop(.willStop)
            }))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        observers.forEach { $0.0.removeObserver($0.1) }
    }


    /// `isPreview` from the host, corrected for small views (MACOS.md §2.4).
    var effectivePreview: Bool {
        SaverLifecycle.isPreview(reported: reportedPreview, width: bounds.width, height: bounds.height)
    }

    // MARK: Lifecycle

    /// The System Settings thumbnail is a snapshot of a view that never gets `startAnimation`
    /// (MACOS.md §2.8), so draw the current frame as soon as there is a window.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { sceneView?.renderNow() }
    }

    override func startAnimation() {
        super.startAnimation()
        let slot = SaverSlot(screen: screenKey, isPreview: effectivePreview)
        if let replaced = Self.registry.activate(ObjectIdentifier(self), in: slot) {
            Self.instances.allObjects.first { ObjectIdentifier($0) == replaced }?.retire()
        }
        sceneView?.start()
        engineTimer?.invalidate()
        engineTimer = Timer.scheduledTimer(withTimeInterval: EngineWatch.pollInterval, repeats: true) { [weak self] _ in
            self?.checkEngine()
        }
    }

    private func checkEngine() {
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: SaverLifecycle.engineBundleIdentifier).isEmpty
        if engineWatch.update(engineRunning: running) { screenSaverWillStop(.engineGone) }
    }

    /// Only reliably called for the System Settings thumbnail (MACOS.md §2.2); cleanup doesn't depend on it.
    override func stopAnimation() {
        super.stopAnimation()
        retire()
    }

    /// Frames come from the scene's own timer (MACOS.md §2.3).
    override func animateOneFrame() {}


    private func retire() {
        engineTimer?.invalidate()
        engineTimer = nil
        sceneView?.stop()
        Self.registry.deactivate(ObjectIdentifier(self))
    }

    private func screenSaverWillStop(_ reason: SaverExitReason) {
        retire()
        if SaverLifecycle.exitsOnWillStop(isPreview: effectivePreview) {
            // The reason is the only thing logged; it carries no user data.
            Self.log.notice("Exiting host: \(reason.rawValue, privacy: .public)")
            // The legacy host never tears instances down (MACOS.md §2.1); terminate() would be ignored.
            exit(0)
        }
    }


    private var screenKey: String {
        let screen = window?.screen ?? NSScreen.main
        if let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.stringValue
        }
        return "unknown"
    }

    private func reloadSettings() {
        guard let settings = Self.store?.load() else { return }
        sceneView?.settings = settings
    }

    // MARK: Options sheet

    override var hasConfigureSheet: Bool { Self.resources != nil && Self.store != nil }

    override var configureSheet: NSWindow? {
        guard let resources = Self.resources, let store = Self.store else { return nil }
        let sheet = OptionsSheet(catalog: resources.core.i18n, fonts: resources.fonts, settings: store.load()) { [weak self] result in
            if let settings = result {
                store.save(settings)
                NotificationCenter.default.post(name: Self.settingsDidChange, object: nil)
            }
            self?.sheet = nil
        }
        self.sheet = sheet
        return sheet.window
    }
}
