import AppKit
import CoreText
import BinaryTimeCore

/// One line of text drawn with Core Text. The fill colour is an animatable layer property so the
/// 600 ms theme inversion interpolates it; everything else is set in place without animation.
public final class GlyphLayer: CALayer {
    @NSManaged public var fgColor: CGColor?

    public var text = "" { didSet { if text != oldValue { setNeedsDisplay() } } }
    public var textStyle: TextStyle? { didSet { if textStyle != oldValue { setNeedsDisplay() } } }
    public var alignment: TextAlignment = .left { didSet { if alignment != oldValue { setNeedsDisplay() } } }
    public var direction: TextDirection = .ltr { didSet { if direction != oldValue { setNeedsDisplay() } } }

    public override init() {
        super.init()
        needsDisplayOnBoundsChange = true
        isOpaque = false
        contentsGravity = .center
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Presentation copies must carry the custom properties so animated redraws have them.
    public override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? GlyphLayer {
            text = other.text
            textStyle = other.textStyle
            alignment = other.alignment
            direction = other.direction
        }
    }

    public override class func needsDisplay(forKey key: String) -> Bool {
        key == "fgColor" ? true : super.needsDisplay(forKey: key)
    }

    public override func action(forKey event: String) -> CAAction? {
        if event == "fgColor" {
            let animation = CABasicAnimation(keyPath: event)
            animation.fromValue = presentation()?.fgColor ?? fgColor
            return animation
        }
        return super.action(forKey: event)
    }

    public override func draw(in ctx: CGContext) {
        guard let style = textStyle, !text.isEmpty, let color = fgColor else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = direction == .rtl ? .rightToLeft : .leftToRight
        paragraph.lineBreakMode = .byClipping
        let attributed = NSAttributedString(string: style.display(text), attributes: [
            .font: style.font,
            .kern: style.tracking,
            .foregroundColor: NSColor(cgColor: color) ?? NSColor.white,
            .paragraphStyle: paragraph,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let advance = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading)) - max(0, style.tracking)
        let x: CGFloat
        switch alignment {
        case .left: x = 0
        case .right: x = bounds.width - advance
        case .center: x = (bounds.width - advance) / 2
        }
        // Core Graphics is y-up: centre the line box in the layer, then place the baseline inside it.
        let lineHeight = style.lineHeight
        let boxBottom = (bounds.height - lineHeight) / 2
        let baseline = boxBottom + (lineHeight - (ascent + descent)) / 2 + descent
        ctx.saveGState()
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setAllowsFontSmoothing(true)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSubpixelPositioning(true)
        ctx.setShouldSubpixelPositionFonts(true)
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
