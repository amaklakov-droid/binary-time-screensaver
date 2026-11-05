import AppKit
import BinaryTimeCore

/// Owns the layer tree and keeps it in sync with `ScreenModel`s. Structure is rebuilt only when the
/// column count or language changes; geometry when the size, scale or layout-affecting texts change;
/// per frame only texts and bit states that differ are touched (SPEC §8).
public final class ClockScene {
    public let rootLayer = CALayer()
    public let tokens: Tokens
    public let fonts: FontRegistry

    public var contentsScale: CGFloat = 2 {
        didSet { if contentsScale != oldValue { glyphs.values.forEach { $0.contentsScale = contentsScale }; rootLayer.contentsScale = contentsScale } }
    }
    /// `NSWorkspace.accessibilityDisplayShouldReduceMotion`: no bit fades, no pulse.
    public var reduceMotion = false { didSet { if reduceMotion != oldValue { updatePulse() } } }
    /// Host-supplied size of the control pills for a given available width, metrics and model (DebugHost only).
    public var controlsSizeProvider: ((CGFloat, LayoutMetrics, ScreenModel) -> CGSize?)? { didSet { needsLayout = true } }

    public private(set) var size: CGSize = .zero
    public private(set) var model: ScreenModel?
    public private(set) var frames: SceneFrames?
    public private(set) var metrics: LayoutMetrics?
    /// > 1 when the scene draws a miniature of a larger virtual screen (previews, tiny windows).
    public private(set) var miniatureScale: CGFloat = 1
    /// Top-left-origin frame for the host's controls in actual points, valid after `apply`.
    public var controlsFrame: CGRect {
        guard let f = frames?.controls, !f.isEmpty else { return .zero }
        let k = miniatureScale
        return CGRect(x: f.minX / k, y: f.minY / k, width: f.width / k, height: f.height / k)
    }

    private var glyphs: [SceneElement: GlyphLayer] = [:]
    private var shapes: [SceneElement: CALayer] = [:]
    private var bits: [SceneElement: BitLayer] = [:]
    private var pulse: PulseLayer?
    private var structureKey: String?
    private var layoutSignature: String?
    private var appliedTheme: Theme?
    private var needsLayout = true

    private let ink: CGColor
    private let paper: CGColor

    public init(tokens: Tokens, fonts: FontRegistry) {
        self.tokens = tokens
        self.fonts = fonts
        ink = ClockScene.color(hex: tokens.ink)
        paper = ClockScene.color(hex: tokens.paper)
        rootLayer.masksToBounds = true
        rootLayer.backgroundColor = ink
        rootLayer.isOpaque = true
    }

    // MARK: Public API

    public func setSize(_ newSize: CGSize) {
        guard newSize != size, newSize.width > 0, newSize.height > 0 else { return }
        size = newSize
        rootLayer.frame = CGRect(origin: .zero, size: newSize)
        needsLayout = true
        if let model { apply(model, animated: false) }
    }

    public func invalidateLayout() {
        needsLayout = true
    }

    public func apply(_ newModel: ScreenModel, animated: Bool) {
        guard size.width > 0, size.height > 0 else { model = newModel; return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let structureChanged = newModel.structureKey != structureKey
        if structureChanged {
            rebuild()
            structureKey = newModel.structureKey
        }
        let signature = ClockScene.layoutSignature(of: newModel)
        if structureChanged || needsLayout || signature != layoutSignature || newModel.bitShape != model?.bitShape {
            relayout(for: newModel)
            layoutSignature = signature
            needsLayout = false
        }
        applyTheme(newModel.theme, animated: animated && appliedTheme != nil && appliedTheme != newModel.theme)
        applyTexts(newModel)
        applyBits(newModel, animated: animated && !structureChanged && model != nil)
        model = newModel
        updatePulse()
    }

    /// Theme-independent fill colour for the current model.
    public var foreground: CGColor { (model?.theme ?? .dark) == .dark ? paper : ink }
    public var background: CGColor { (model?.theme ?? .dark) == .dark ? ink : paper }

    // MARK: Structure

    private func rebuild() {
        glyphs.values.forEach { $0.removeFromSuperlayer() }
        shapes.values.forEach { $0.removeFromSuperlayer() }
        bits.values.forEach { $0.removeFromSuperlayer() }
        glyphs = [:]
        shapes = [:]
        bits = [:]
        pulse = nil
    }

    private func glyph(_ element: SceneElement) -> GlyphLayer {
        if let layer = glyphs[element] { return layer }
        let layer = GlyphLayer()
        layer.contentsScale = contentsScale
        layer.fgColor = foreground
        rootLayer.addSublayer(layer)
        glyphs[element] = layer
        return layer
    }

    private func shape(_ element: SceneElement) -> CALayer {
        if let layer = shapes[element] { return layer }
        let layer: CALayer
        if element == .pulse {
            let p = PulseLayer()
            pulse = p
            layer = p
        } else {
            layer = CALayer()
        }
        layer.contentsScale = contentsScale
        rootLayer.addSublayer(layer)
        shapes[element] = layer
        return layer
    }

    private func bit(_ element: SceneElement) -> BitLayer {
        if let layer = bits[element] { return layer }
        let layer = BitLayer()
        layer.contentsScale = contentsScale
        rootLayer.addSublayer(layer)
        bits[element] = layer
        return layer
    }

    // MARK: Layout

    /// Texts whose width or presence moves other elements, plus the theme (the host restyles its controls
    /// during layout). Row decimals and the readout digits are tabular, so they never trigger a relayout.
    static func layoutSignature(of m: ScreenModel) -> String {
        [m.theme.rawValue, m.header.title, m.header.calendarLine, m.header.dateLine,
         m.location.tag, m.location.l1, m.location.l2, m.location.l3,
         m.separatorLabel, m.footer.dayPeriod.isEmpty ? "" : "ampm", m.footer.utcOffset,
         m.footer.readout.count.description, m.showControls.description,
         m.rows.map { $0.label + "|" + $0.sub }.joined(separator: "|")].joined(separator: "\u{1F}")
    }

    private func relayout(for newModel: ScreenModel) {
        let provider = controlsSizeProvider
        guard let fitted = try? SceneLayout.fit(model: newModel, tokens: tokens, fonts: fonts, size: size, controlsSize: { width, metrics in
            guard newModel.showControls, let provider else { return nil }
            return provider(width, metrics, newModel)
        }) else { return }
        let metrics = fitted.metrics
        let frames = fitted.frames
        self.metrics = metrics
        self.frames = frames
        miniatureScale = fitted.scale
        rootLayer.sublayerTransform = fitted.scale == 1 ? CATransform3DIdentity : CATransform3DMakeScale(1 / fitted.scale, 1 / fitted.scale, 1)
        let virtualHeight = frames.size.height

        for (element, layer) in glyphs where frames.texts[element] == nil { layer.isHidden = true }
        for (element, placement) in frames.texts {
            let layer = glyph(element)
            layer.isHidden = false
            layer.frame = flip(placement.frame, height: virtualHeight)
            layer.textStyle = placement.style
            layer.alignment = placement.alignment
            layer.direction = placement.direction
            layer.opacity = Float(placement.style.opacity)
            layer.setNeedsDisplay()
        }

        for (element, layer) in shapes where frames.shapes[element] == nil { layer.isHidden = true }
        for (element, rect) in frames.shapes {
            switch element {
            case .bit(let metric, _):
                let layer = bit(element)
                layer.isHidden = false
                layer.position = CGPoint(x: rect.midX, y: virtualHeight - rect.midY)
                layer.configure(bitAppearance(for: metric, model: newModel, metrics: metrics, frames: frames))
            default:
                let layer = shape(element)
                layer.isHidden = false
                layer.frame = flip(rect, height: virtualHeight)
                configureShape(element, layer: layer, model: newModel, metrics: metrics)
            }
        }
        for (element, layer) in bits where frames.shapes[element] == nil { layer.isHidden = true }
    }

    private func flip(_ rect: CGRect, height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    private func bitAppearance(for metric: Metric, model: ScreenModel, metrics: LayoutMetrics, frames: SceneFrames) -> BitLayer.Appearance {
        BitLayer.Appearance(size: frames.bitSize[metric] ?? CGFloat(metrics.bit),
                            shape: model.bitShape,
                            squareRadius: CGFloat(metrics.squareRadius),
                            outline: CGFloat(metrics.offOutline),
                            voidScale: CGFloat(tokens.bit.voidScale),
                            lowOpacity: Float(tokens.opacity.low),
                            ghostOpacity: Float(tokens.opacity.ghost),
                            color: model.theme == .dark ? paper : ink)
    }

    private func configureShape(_ element: SceneElement, layer: CALayer, model: ScreenModel, metrics: LayoutMetrics) {
        let fg = model.theme == .dark ? paper : ink
        switch element {
        case .pulse:
            layer.backgroundColor = fg
            layer.cornerRadius = layer.bounds.height / 2
            layer.opacity = 1
        case .separatorRule:
            layer.backgroundColor = fg
            layer.opacity = Float(tokens.opacity.rule)
        case .legendDotOn:
            layer.backgroundColor = fg
            layer.borderWidth = 0
            layer.cornerRadius = model.bitShape == .dot ? layer.bounds.height / 2 : 2
            layer.opacity = 1
        case .legendDotOff:
            layer.backgroundColor = nil
            layer.borderColor = fg
            layer.borderWidth = 1
            layer.cornerRadius = model.bitShape == .dot ? layer.bounds.height / 2 : 2
            layer.opacity = 1
        default:
            break
        }
    }

    // MARK: Per-frame updates

    private func applyTexts(_ newModel: ScreenModel) {
        guard let frames else { return }
        for element in frames.texts.keys {
            glyphs[element]?.text = ClockScene.text(for: element, in: newModel)
        }
    }

    static func text(for element: SceneElement, in m: ScreenModel) -> String {
        switch element {
        case .title: return m.header.title
        case .calendarLine: return m.header.calendarLine
        case .dateLine: return m.header.dateLine
        case .locationTag: return m.location.tag
        case .locationL1: return m.location.l1
        case .locationL2: return m.location.l2
        case .locationL3: return m.location.l3
        case .placeLabel: return "2ⁿ"
        case .placeValue(let i): return i < m.placeValues.count ? m.placeValues[i] : ""
        case .rowLabel(let metric): return m.rows[metric.rawValue].label
        case .rowSub(let metric): return m.rows[metric.rawValue].sub
        case .rowDecimal(let metric): return m.rows[metric.rawValue].decimal
        case .separatorLabel: return m.separatorLabel
        case .readout: return m.footer.readout
        case .dayPeriod: return m.footer.dayPeriod
        case .legendOne: return "1"
        case .legendZero: return "0"
        case .legendOffset: return m.footer.utcOffset
        case .bit, .pulse, .separatorRule, .legendDotOn, .legendDotOff: return ""
        }
    }

    private func applyBits(_ newModel: ScreenModel, animated: Bool) {
        guard let metrics, let frames else { return }
        let previous = model
        for row in newModel.rows {
            let oldStates = previous?.rows[row.metric.rawValue].states
            let changed = oldStates != row.states
            let shapeChanged = previous?.bitShape != newModel.bitShape || previous?.theme != newModel.theme
            guard changed || shapeChanged || previous == nil else { continue }
            let appearance = bitAppearance(for: row.metric, model: newModel, metrics: metrics, frames: frames)
            let fade = animated && !reduceMotion && changed && !shapeChanged
            CATransaction.begin()
            CATransaction.setDisableActions(!fade)
            if fade { CATransaction.setAnimationDuration(tokens.motion.bit) }
            for (i, state) in row.states.enumerated() {
                guard let layer = bits[.bit(row.metric, i)] else { continue }
                if state != layer.state || shapeChanged || previous == nil {
                    layer.apply(state: state, appearance: appearance)
                }
            }
            CATransaction.commit()
        }
    }

    private func applyTheme(_ theme: Theme, animated: Bool) {
        guard theme != appliedTheme || model == nil else { return }
        appliedTheme = theme
        let fg = theme == .dark ? paper : ink
        let bg = theme == .dark ? ink : paper
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        if animated { CATransaction.setAnimationDuration(tokens.motion.theme) }
        rootLayer.backgroundColor = bg
        for layer in glyphs.values { layer.fgColor = fg }
        for (element, layer) in shapes {
            if element == .legendDotOff { layer.borderColor = fg } else { layer.backgroundColor = fg }
        }
        for layer in bits.values {
            layer.borderColor = fg
            if layer.state != .off { layer.backgroundColor = fg }
        }
        CATransaction.commit()
    }

    private func updatePulse() {
        pulse?.setPulsing(!reduceMotion, period: tokens.motion.locationPulse, minimumOpacity: Float(tokens.motion.pulseMinimumOpacity))
    }

    // MARK: Helpers

    public static func color(hex: String) -> CGColor {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard let value = UInt32(text, radix: 16) else { return CGColor(gray: 0, alpha: 1) }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
