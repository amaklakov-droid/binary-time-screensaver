import AppKit
import BinaryTimeCore
import BinaryTimeUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let options: HostOptions
    private var window: NSWindow!
    private var container: NSView!
    private var sceneView: ClockSceneView!
    private var controls: ControlsBar!
    private var keyMonitor: Any?
    private let defaults = UserDefaults.standard
    private static let settingsKey = "settings"

    init(options: HostOptions) {
        self.options = options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let resources: AppResources
        do {
            resources = try AppResources(bundle: .main)
        } catch {
            fail("Cannot load resources: \(error)")
            return
        }
        if !resources.fonts.isComplete {
            FileHandle.standardError.write("warning: fonts missing from bundle: \(resources.fonts.missingFamilies.joined(separator: ", ")) — using system fallback\n".data(using: .utf8)!)
        }
        for error in options.errors { FileHandle.standardError.write("warning: \(error)\n".data(using: .utf8)!) }

        let stored = options.reset ? Settings.default : Settings(dictionary: defaults.dictionary(forKey: AppDelegate.settingsKey) ?? [:])
        let settings = options.apply(to: stored)

        let contentRect = NSRect(origin: .zero, size: options.size)
        window = NSWindow(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Binary Time — DebugHost"
        window.minSize = NSSize(width: 320, height: 240)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black

        container = NSView(frame: contentRect)
        container.autoresizingMask = [.width, .height]
        sceneView = ClockSceneView(resources: resources, settings: settings, frame: contentRect)
        sceneView.autoresizingMask = [.width, .height]
        container.addSubview(sceneView)
        if let freeze = options.freeze { sceneView.clock = { freeze } }
        if let tz = options.timeZone { sceneView.composer.timeZone = tz }
        if let index = options.spaceIndex {
            let catalog = resources.core.catalog
            sceneView.composer.spaceRotator = SpaceRotator(count: catalog.objects.count, period: catalog.rotateEverySeconds,
                                                           epoch: options.freeze ?? Date(), startIndex: index)
        }
        sceneView.monitorsVPN = options.freeze == nil && !options.isHeadless
        window.contentView = container

        ControlsBar.sharedTokens = resources.core.tokens
        controls = ControlsBar(frame: .zero)
        controls.fontsProxy = resources.fonts
        controls.isHidden = true
        controls.onAction = { [weak self] action in self?.perform(action) }
        container.addSubview(controls)
        sceneView.onControlsFrameChange = { [weak self] frame in
            guard let self else { return }
            controls.isHidden = frame.isEmpty
            if !frame.isEmpty { controls.frame = frame }
        }
        sceneView.controlsHost = controls

        if options.isHeadless {
            sceneView.renderNow()
            DispatchQueue.main.async { [self] in takeScreenshot() }
            return
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        sceneView.start()
        installKeyMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: Actions (prototype `actions` + keys L/H/C/V/I/S)

    private func perform(_ action: ControlsBar.Action) {
        var s = sceneView.settings
        switch action {
        case .language:
            let current = s.language.resolve(preferredLanguages: sceneView.composer.preferredLanguages)
            s.language = .fixed(current.next)
        case .hourFormat:
            s.hourFormat = s.hourFormat == .h12 ? .h24 : .h12
        case .calendar:
            let all = CalendarSetting.allCases
            s.calendar = all[(all.firstIndex(of: s.calendar)! + 1) % all.count]
        case .location:
            s.location = s.location == .vpn ? .auto : .vpn
            sceneView.composer.spaceRotator.advance()
        case .invert:
            s.theme = s.theme == .light ? .dark : .light
        }
        apply(s)
    }

    private func apply(_ s: Settings) {
        sceneView.settings = s
        defaults.set(s.dictionaryRepresentation, forKey: AppDelegate.settingsKey)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !event.modifierFlags.contains(.command) else { return event }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "l": perform(.language)
            case "h": perform(.hourFormat)
            case "c": perform(.calendar)
            case "v": perform(.location)
            case "i": perform(.invert)
            case "s":
                var s = sceneView.settings
                s.showControls.toggle()
                apply(s)
            default: return event
            }
            return nil
        }
    }

    // MARK: Screenshot

    private func takeScreenshot() {
        guard let url = options.screenshot else { return }
        container.layoutSubtreeIfNeeded()
        sceneView.renderNow()
        guard let sceneImage = sceneView.snapshot(scale: options.scale) else { fail("Snapshot failed"); return }
        let image = controls.isHidden ? sceneImage : (Screenshot.composite(sceneImage, overlay: controls, at: controls.frame, scale: options.scale) ?? sceneImage)
        do {
            try Screenshot.writePNG(image, to: url)
            print(url.path)
            NSApp.terminate(nil)
        } catch {
            fail("Cannot write screenshot: \(error)")
        }
    }

    private func fail(_ message: String) {
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
        exit(1)
    }
}
