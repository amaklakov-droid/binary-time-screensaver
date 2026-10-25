import AppKit
import BinaryTimeCore

public enum TextAlignment: Equatable { case left, right, center }

/// A resolved text style: font, tracking in points, case rule, opacity and line height.
public struct TextStyle: Equatable {
    public var font: NSFont
    public var tracking: CGFloat
    public var uppercase: Bool
    public var opacity: CGFloat
    public var lineHeight: CGFloat

    public init(font: NSFont, trackingEm: CGFloat, uppercase: Bool, opacity: CGFloat, lineHeightMultiple: CGFloat?) {
        self.font = font
        self.tracking = trackingEm * font.pointSize
        self.uppercase = uppercase
        self.opacity = opacity
        if let multiple = lineHeightMultiple {
            self.lineHeight = (multiple * font.pointSize).rounded(.up)
        } else {
            self.lineHeight = (font.ascender - font.descender + font.leading).rounded(.up)
        }
    }

    public var ascent: CGFloat { font.ascender }
    public var descent: CGFloat { -font.descender }

    public func display(_ text: String) -> String {
        uppercase ? text.uppercased() : text
    }

    /// Advance width of `text` with this style, trailing tracking excluded (CSS letter-spacing semantics).
    public func width(of text: String) -> CGFloat {
        let shown = display(text)
        guard !shown.isEmpty else { return 0 }
        let attributed = NSAttributedString(string: shown, attributes: [.font: font, .kern: tracking])
        return max(0, attributed.size().width - tracking)
    }

    /// Top of a frame of height `lineHeight` whose baseline sits at `baselineY` (top-left coordinates).
    public func frameTop(forBaseline baselineY: CGFloat) -> CGFloat {
        baselineY - ascent - (lineHeight - (ascent + descent)) / 2
    }

    /// Baseline offset from the top of a frame of height `lineHeight`.
    public var baselineFromTop: CGFloat {
        (lineHeight - (ascent + descent)) / 2 + ascent
    }
}

/// Values the prototype keeps in `prototype/styles.css` rather than in `tokens.json`.
/// Listed here once, with their origin, so nothing is scattered through the layout code.
public enum PrototypeStyle {
    /// `.bt-block { gap: .35em }` — vertical gap between header/footer block lines, × base font size.
    public static let blockLineGapEm: CGFloat = 0.35
    /// `.bt-pulse { width: .55em }` — pulse dot size, × kicker font size.
    public static let pulseSizeEm: CGFloat = 0.55
    /// `.bt-k { gap: .6em }` — gap between pulse dot and tag text, × kicker font size.
    public static let pulseGapEm: CGFloat = 0.6
    /// `.bt-label { gap: .25em }` — gap between row label and sub-label, × label font size.
    public static let labelSubGapEm: CGFloat = 0.25
    /// `.bt-sep { gap: 1em }` — gap between separator label and rule, × separator font size.
    public static let separatorGapEm: CGFloat = 1.0
    /// `.bt-ampm { font-size: .6em; letter-spacing: .2em; margin-inline-start: .6em }`, relative to the readout.
    public static let dayPeriodSizeFactor: CGFloat = 0.6
    public static let dayPeriodTrackingEm: CGFloat = 0.2
    public static let dayPeriodMarginEm: CGFloat = 0.6
    /// `.bt-legend { font-size: .8em; letter-spacing: .12em; gap: 1.6em; margin-top: .6em }` and `.lg { width: .8em }`, `span { gap: .6em }`.
    public static let legendSizeEm: CGFloat = 0.8
    public static let legendTrackingEm: CGFloat = 0.12
    public static let legendItemGapEm: CGFloat = 1.6
    public static let legendMarginTopEm: CGFloat = 0.6
    public static let legendGlyphEm: CGFloat = 0.8
    public static let legendGlyphGapEm: CGFloat = 0.6
    /// `.bt-head { margin-bottom: calc(var(--gap) * -.4) }` — pulls the date group up under the place values.
    public static let placeRowOverlapFactor: CGFloat = 0.4
    /// Narrow layout: `.bt-top { gap: 14px }`, `.bt-row { row-gap: 8px }`, `.bt-label { gap: .8em }`.
    public static let narrowHeaderGap: CGFloat = 14
    public static let narrowRowGap: CGFloat = 8
    public static let narrowLabelGapEm: CGFloat = 0.8
}

/// Turns token text styles into `TextStyle`s for one base font size and one language's script rules.
public struct StyleSheet {
    public let tokens: Tokens
    public let fonts: FontRegistry
    public let metrics: LayoutMetrics
    /// Tracking and uppercase apply only to Latin/Cyrillic (`i18n.meta.caps`).
    public let caps: Bool
    public let lineHeightMultiple: CGFloat?

    public init(tokens: Tokens, fonts: FontRegistry, metrics: LayoutMetrics, caps: Bool, lineHeightMultiple: Double?) {
        self.tokens = tokens
        self.fonts = fonts
        self.metrics = metrics
        self.caps = caps
        self.lineHeightMultiple = lineHeightMultiple.map { CGFloat($0) }
    }

    public var baseSize: CGFloat { CGFloat(metrics.fontSize) }

    func size(_ expression: TokenExpression, relativeTo base: CGFloat) -> CGFloat {
        let env = ExpressionEnvironment(width: metrics.width, height: metrics.height, fontSize: Double(base),
                                        variables: ["b": metrics.bit, "pad": metrics.pad, "gap": metrics.gap])
        return CGFloat((try? expression.evaluate(in: env)) ?? Double(base))
    }

    public func style(size: CGFloat, weight: Int, trackingEm: Double, uppercase: Bool, opacity: Double) -> TextStyle {
        TextStyle(font: fonts.font(weight: weight, size: size),
                  trackingEm: caps ? CGFloat(trackingEm) : 0,
                  uppercase: caps && uppercase,
                  opacity: CGFloat(opacity),
                  lineHeightMultiple: lineHeightMultiple)
    }

    func style(_ token: Tokens.TextStyle, weight: Int? = nil, relativeTo base: CGFloat? = nil, opacity: Double? = nil) -> TextStyle {
        style(size: size(token.size, relativeTo: base ?? baseSize),
              weight: weight ?? token.weight ?? 400,
              trackingEm: token.tracking,
              uppercase: token.uppercase,
              opacity: opacity ?? token.opacity)
    }

    public var kicker: TextStyle { style(tokens.type.kicker) }
    public var value: TextStyle { style(tokens.type.value) }
    public var note: TextStyle { style(tokens.type.note) }
    public var rowLabelDate: TextStyle { style(tokens.type.rowLabel, weight: tokens.type.rowLabelWeightDate, opacity: tokens.opacity.mid) }
    public var rowLabelTime: TextStyle { style(tokens.type.rowLabel, weight: tokens.type.rowLabelWeightTime, opacity: 1) }
    /// `.bt-sub` is nested in `.bt-label`, so its em size is relative to the label size; never uppercased.
    public var rowSub: TextStyle {
        let labelSize = size(tokens.type.rowLabel.size, relativeTo: baseSize)
        return style(size: size(tokens.type.rowSub.size, relativeTo: labelSize), weight: 400,
                     trackingEm: tokens.type.rowSub.tracking, uppercase: false, opacity: tokens.type.rowSub.opacity)
    }
    public var decimalTime: TextStyle {
        style(size: CGFloat(metrics.decimalTimeSize), weight: tokens.type.decimalWeightTime, trackingEm: 0.02, uppercase: false, opacity: 1)
    }
    public var decimalDate: TextStyle {
        style(size: CGFloat(metrics.decimalDateSize), weight: tokens.type.decimalWeightDate, trackingEm: 0.02, uppercase: false, opacity: tokens.opacity.mid)
    }
    public var place: TextStyle {
        style(size: CGFloat(metrics.placeSize), weight: 400, trackingEm: 0, uppercase: false, opacity: tokens.type.placeOpacity)
    }
    public var separator: TextStyle { style(tokens.type.separator) }
    public var readout: TextStyle {
        style(size: CGFloat(metrics.readoutSize), weight: tokens.type.readoutWeight, trackingEm: tokens.type.readoutTracking, uppercase: false, opacity: 1)
    }
    public var dayPeriod: TextStyle {
        style(size: CGFloat(metrics.readoutSize) * PrototypeStyle.dayPeriodSizeFactor, weight: tokens.fontWeights["semibold"] ?? 600,
              trackingEm: Double(PrototypeStyle.dayPeriodTrackingEm), uppercase: false, opacity: 1)
    }
    public var legend: TextStyle {
        style(size: baseSize * PrototypeStyle.legendSizeEm, weight: 400, trackingEm: Double(PrototypeStyle.legendTrackingEm), uppercase: true, opacity: tokens.opacity.mid)
    }
    public var button: TextStyle { style(tokens.type.button, weight: 400, opacity: 1) }
}
