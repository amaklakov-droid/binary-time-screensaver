import AppKit
import BinaryTimeCore

/// Layer-hosting view that drives a `ClockScene` from a `FrameComposer` on a display link.
/// Shared by the screen saver and DebugHost; the saver adds its lifecycle on top (MACOS.md §2).
public final class ClockSceneView: NSView {
    public let scene: ClockScene
    public let composer: FrameComposer
    public let resources: AppResources

    /// Source of time; DebugHost freezes it for screenshots.
    public var clock: () -> Date = { Date() }
    /// Lower frame rate for System Settings previews (0 = every display refresh).
    public var maximumFramesPerSecond: Int = 0
    /// Layer-1 VPN check (SPEC §4.4). Off in tests and screenshots.
    public var monitorsVPN = true {
        didSet { if isRunning { configureVPNMonitoring() } }
    }
    /// The host's control pills. They must live in a *sibling* view (a layer-hosting view has no subviews);
    /// the scene asks this object for its size and reports where to put it through `onControlsFrameChange`.
    public weak var controlsHost: ControlsSizing? {
        didSet {
            if let host = controlsHost {
                scene.controlsSizeProvider = { [weak host] width, metrics, model in
                    host?.preferredSize(forWidth: width, metrics: metrics, model: model)
                }
            } else {
                scene.controlsSizeProvider = nil
            }
            scene.invalidateLayout()
            renderNow()
        }
    }
    /// Frame for the controls in this view's coordinates (y-up); `.zero` when they are hidden.
    public private(set) var controlsFrame: NSRect = .zero
    public var onControlsFrameChange: ((NSRect) -> Void)?

    public private(set) var isRunning = false
    private var displayLink: CADisplayLink?
    private var lastHundredth: Int64 = .min
    private var lastFrameTime: CFTimeInterval = 0
    private var vpnMonitor: VPNChangeMonitor?
    private let vpnDetector = LocalVPNDetector(provider: SystemPrimaryInterfaceProvider())
    private var observers: [NSObjectProtocol] = []

    public init(resources: AppResources, settings: Settings, frame: NSRect) {
        self.resources = resources
        self.scene = ClockScene(tokens: resources.core.tokens, fonts: resources.fonts)
        self.composer = FrameComposer(resources: resources.core, settings: settings)
        super.init(frame: frame)
        // Layer-hosting: assign the layer first, then opt in. AppKit then leaves the layer tree to us.
        layer = scene.rootLayer
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        scene.setSize(frame.size)
        scene.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.scene.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refreshVPNState()
            })
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        stop()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    // MARK: Settings

    public var settings: Settings {
        get { composer.settings }
        set {
            guard newValue != composer.settings else { return }
            composer.settings = newValue
            renderNow()
        }
    }

    // MARK: Running

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        let link = displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        configureVPNMonitoring()
        renderNow()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        vpnMonitor?.stop()
        vpnMonitor = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if maximumFramesPerSecond > 0 {
            let minInterval = 1.0 / Double(maximumFramesPerSecond)
            if link.targetTimestamp - lastFrameTime < minInterval * 0.9 { return }
            lastFrameTime = link.targetTimestamp
        }
        let now = clock()
        let hundredth = Int64((now.timeIntervalSince1970 * 100).rounded(.down))
        if hundredth == lastHundredth { return }
        lastHundredth = hundredth
        render(at: now, animated: true)
    }

    /// Renders the current instant immediately (after a settings or size change).
    public func renderNow() {
        lastHundredth = .min
        render(at: clock(), animated: false)
    }

    private func render(at instant: Date, animated: Bool) {
        let model = composer.frame(at: instant)
        scene.apply(model, animated: animated)
        publishControlsFrame()
    }

    // MARK: Geometry

    public override var isFlipped: Bool { false }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        scene.setSize(newSize)
        publishControlsFrame()
    }

    public override func layout() {
        super.layout()
        scene.setSize(bounds.size)
        publishControlsFrame()
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        scene.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        viewDidChangeBackingProperties()
    }

    private func publishControlsFrame() {
        let f = scene.controlsFrame
        let visible = controlsHost != nil && scene.model?.showControls == true && !f.isEmpty
        let frame = visible ? NSRect(x: f.minX, y: bounds.height - f.maxY, width: f.width, height: f.height) : .zero
        guard frame != controlsFrame else { return }
        controlsFrame = frame
        onControlsFrameChange?(frame)
    }

    // MARK: VPN

    private func configureVPNMonitoring() {
        vpnMonitor?.stop()
        vpnMonitor = nil
        guard monitorsVPN else {
            composer.vpnDetected = false
            return
        }
        refreshVPNState()
        let monitor = VPNChangeMonitor { [weak self] in
            DispatchQueue.main.async { self?.refreshVPNState() }
        }
        monitor.start()
        vpnMonitor = monitor
    }

    private func refreshVPNState() {
        guard monitorsVPN else { return }
        let detected = vpnDetector.isVPNActive()
        if detected != composer.vpnDetected {
            composer.vpnDetected = detected
            renderNow()
        }
    }

    // MARK: Snapshot

    /// Renders the layer tree into an image, `scale` pixels per point.
    public func snapshot(scale: CGFloat = 1) -> CGImage? {
        let width = Int((bounds.width * scale).rounded()), height = Int((bounds.height * scale).rounded())
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.scaleBy(x: scale, y: scale)
        CATransaction.flush()
        scene.rootLayer.render(in: context)
        return context.makeImage()
    }
}

/// Control hosts restyle themselves for the current metrics and model and report their wrapped size.
public protocol ControlsSizing: AnyObject {
    func preferredSize(forWidth width: CGFloat, metrics: LayoutMetrics, model: ScreenModel) -> CGSize
}
