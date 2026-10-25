import AppKit
import BinaryTimeCore
import BinaryTimeUI

/// The design's control pills (SPEC §6): language, time format, calendar, location, invert.
/// DebugHost only; the running screen saver has no controls.
final class ControlsBar: NSView, ControlsSizing {
    enum Action: CaseIterable { case language, hourFormat, calendar, location, invert }

    var onAction: ((Action) -> Void)?

    private var pills: [Action: PillButton] = [:]
    private var gap: CGFloat = 8
    private var direction: TextDirection = .ltr
    private var rowHeight: CGFloat = 44
    private var rows: [[Action]] = [Action.allCases]

    override init(frame: NSRect) {
        super.init(frame: frame)
        for action in Action.allCases {
            let pill = PillButton()
            pill.showsGlobe = action == .language
            pill.onPress = { [weak self] in self?.onAction?(action) }
            addSubview(pill)
            pills[action] = pill
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    // MARK: ControlsSizing

    func preferredSize(forWidth width: CGFloat, metrics: LayoutMetrics, model: ScreenModel) -> CGSize {
        let tokens = model.tokensProxy
        let sheet = StyleSheet(tokens: tokens, fonts: fontsProxy, metrics: metrics, caps: model.caps, lineHeightMultiple: model.lineHeight)
        restyle(sheet: sheet, tokens: tokens, model: model)
        // Flow layout: wrap pills into rows that fit `width`.
        rows = []
        var current: [Action] = []
        var x: CGFloat = 0
        for action in Action.allCases {
            let w = pills[action]!.intrinsicContentSize.width
            if !current.isEmpty, x + w > width {
                rows.append(current)
                current = []
                x = 0
            }
            current.append(action)
            x += w + gap
        }
        if !current.isEmpty { rows.append(current) }
        let widest = rows.map { row in row.reduce(0) { $0 + pills[$1]!.intrinsicContentSize.width } + CGFloat(row.count - 1) * gap }.max() ?? 0
        let height = CGFloat(rows.count) * rowHeight + CGFloat(max(0, rows.count - 1)) * gap
        return CGSize(width: min(widest, width), height: height)
    }

    /// Set once by the host; the scene hands us metrics and model per layout.
    var tokensProxy: Tokens!
    var fontsProxy: FontRegistry!

    private func restyle(sheet: StyleSheet, tokens: Tokens, model: ScreenModel) {
        gap = CGFloat(tokens.button.gap)
        rowHeight = CGFloat(tokens.button.minHeight)
        direction = model.direction
        let fg = NSColor(cgColor: ClockScene.color(hex: model.theme == .dark ? tokens.paper : tokens.ink)) ?? .white
        let texts: [Action: String] = [
            .language: model.controls.language,
            .hourFormat: model.controls.hourFormat,
            .calendar: model.controls.calendar,
            .location: model.controls.location,
            .invert: model.controls.invert,
        ]
        let labels: [Action: String] = [
            .language: model.controls.languageAccessibility,
            .hourFormat: model.controls.hourFormat,
            .calendar: model.controls.calendar,
            .location: model.controls.location,
            .invert: model.controls.invert,
        ]
        for (action, pill) in pills {
            pill.configure(text: texts[action] ?? "", accessibilityLabel: labels[action] ?? "",
                           style: sheet.button, color: fg, paddingX: CGFloat(tokens.button.paddingX), minHeight: rowHeight,
                           restOpacity: CGFloat(tokens.button.opacityRest), hoverOpacity: CGFloat(tokens.button.opacityHover),
                           direction: model.direction)
        }
        setAccessibilityLabel(model.controls.groupLabel)
    }

    override func layout() {
        super.layout()
        var y: CGFloat = 0
        for row in rows {
            let rowW = row.reduce(0) { $0 + pills[$1]!.intrinsicContentSize.width } + CGFloat(row.count - 1) * gap
            // Wide: pills hug the end edge; in RTL the order runs right-to-left.
            var x: CGFloat = direction == .rtl ? 0 : bounds.width - rowW
            if direction == .rtl {
                var cursor: CGFloat = rowW
                for action in row {
                    let w = pills[action]!.intrinsicContentSize.width
                    pills[action]!.frame = NSRect(x: cursor - w, y: y, width: w, height: rowHeight)
                    cursor -= w + gap
                }
            } else {
                for action in row {
                    let w = pills[action]!.intrinsicContentSize.width
                    pills[action]!.frame = NSRect(x: x, y: y, width: w, height: rowHeight)
                    x += w + gap
                }
            }
            y += rowHeight + gap
        }
    }
}

private extension ScreenModel {
    /// Tokens are not part of the model; the bar reads them from the host-set proxy.
    var tokensProxy: Tokens { ControlsBar.sharedTokens! }
}

extension ControlsBar {
    static var sharedTokens: Tokens?
}

/// A pill-shaped button: 1 px outline, uppercase tracked label, 66 % at rest, 100 % on hover/focus.
final class PillButton: NSControl {
    var onPress: (() -> Void)?
    var showsGlobe = false

    private var text = ""
    private var style: TextStyle?
    private var color: NSColor = .white
    private var paddingX: CGFloat = 16
    private var minHeight: CGFloat = 44
    private var restOpacity: CGFloat = 0.66
    private var hoverOpacity: CGFloat = 1
    private var direction: TextDirection = .ltr
    private var hovered = false
    private var pressed = false
    private var tracking: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityRole(.button)
        setAccessibilityElement(true)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var focusRingType: NSFocusRingType { get { .exterior } set {} }

    func configure(text: String, accessibilityLabel: String, style: TextStyle, color: NSColor, paddingX: CGFloat, minHeight: CGFloat,
                   restOpacity: CGFloat, hoverOpacity: CGFloat, direction: TextDirection) {
        self.text = text
        self.style = style
        self.color = color
        self.paddingX = paddingX
        self.minHeight = minHeight
        self.restOpacity = restOpacity
        self.hoverOpacity = hoverOpacity
        self.direction = direction
        setAccessibilityLabel(accessibilityLabel)
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    private var globeSize: CGFloat { (style?.font.pointSize ?? 11) * 1.2 }
    private var globeGap: CGFloat { (style?.font.pointSize ?? 11) * 0.5 }

    override var intrinsicContentSize: NSSize {
        guard let style else { return NSSize(width: 44, height: minHeight) }
        let textW = style.width(of: text)
        let iconW = showsGlobe ? globeSize + globeGap : 0
        return NSSize(width: ceil(textW + iconW + 2 * paddingX), height: minHeight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent) { pressed = true; needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        pressed = false
        needsDisplay = true
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onPress?() }
    }
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " || event.keyCode == 36 { onPress?() } else { super.keyDown(with: event) }
    }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }

    override func draw(_ dirtyRect: NSRect) {
        guard let style else { return }
        let focused = window?.firstResponder === self && (window?.isKeyWindow ?? false)
        let alpha = hovered || focused || pressed ? hoverOpacity : restOpacity
        let ink = color.withAlphaComponent(alpha)
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        outline.lineWidth = 1
        ink.setStroke()
        outline.stroke()
        if focused {
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: -3, dy: -3), xRadius: bounds.height / 2 + 3, yRadius: bounds.height / 2 + 3)
            ring.lineWidth = 2
            color.setStroke()
            ring.stroke()
        }
        let attributed = NSAttributedString(string: style.display(text), attributes: [.font: style.font, .kern: style.tracking, .foregroundColor: ink])
        let textW = style.width(of: text)
        let iconW = showsGlobe ? globeSize + globeGap : 0
        let contentW = textW + iconW
        var x = (bounds.width - contentW) / 2
        let lineBottom = (bounds.height - (style.ascent + style.descent)) / 2
        if showsGlobe {
            let iconX = direction == .rtl ? x + textW + globeGap : x
            drawGlobe(in: NSRect(x: iconX, y: (bounds.height - globeSize) / 2, width: globeSize, height: globeSize), color: ink)
            if direction == .ltr { x += iconW }
        }
        attributed.draw(at: NSPoint(x: x, y: lineBottom))
    }

    /// The prototype's globe: circle, equator, one meridian ellipse.
    private func drawGlobe(in rect: NSRect, color: NSColor) {
        color.setStroke()
        let inset = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
        let circle = NSBezierPath(ovalIn: inset)
        circle.lineWidth = max(1, rect.width / 16)
        circle.stroke()
        let equator = NSBezierPath()
        equator.move(to: NSPoint(x: inset.minX, y: inset.midY))
        equator.line(to: NSPoint(x: inset.maxX, y: inset.midY))
        equator.lineWidth = circle.lineWidth
        equator.stroke()
        let meridian = NSBezierPath(ovalIn: NSRect(x: inset.midX - inset.width * 0.21, y: inset.minY, width: inset.width * 0.42, height: inset.height))
        meridian.lineWidth = circle.lineWidth
        meridian.stroke()
    }
}
