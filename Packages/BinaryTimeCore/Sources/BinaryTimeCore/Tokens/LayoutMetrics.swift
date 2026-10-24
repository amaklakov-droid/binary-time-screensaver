import Foundation

/// Lengths derived from the tokens for one container size and column count (SPEC §2.3, tokens `space.*`, `bit.*`).
/// Rect-level placement lives in the UI layer; this is the font-independent arithmetic.
public struct LayoutMetrics: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var columns: Int
    public var isNarrow: Bool
    public var fontSize: Double
    public var pad: Double
    public var gap: Double
    public var labelColumn: Double
    public var decimalColumn: Double
    /// Time-row bit size `b`.
    public var bit: Double
    /// Date-row bit size (`b × dateScale`).
    public var dateBit: Double
    public var offOutline: Double
    public var voidDot: Double
    public var squareRadius: Double
    public var decimalTimeSize: Double
    public var decimalDateSize: Double
    public var placeSize: Double
    public var readoutSize: Double
    public var separatorMargin: Double
    public var dateRowGap: Double
    public var chromeGap: Double

    /// Width of the centred bit block: label column, `w` bits with `w + 1` gaps, decimal column.
    public var bitBlockWidth: Double {
        labelColumn + Double(columns) * bit + Double(columns + 1) * gap + decimalColumn
    }

    /// Width of the bit grid alone: `w` bits and `w − 1` gaps.
    public var gridWidth: Double {
        Double(columns) * bit + Double(columns - 1) * gap
    }

    /// Horizontal offset of column `index` (0 = most significant, left) inside the grid, for `size` bits
    /// centred in `b`-wide cells.
    public func cellOffsetX(column index: Int, size: Double) -> Double {
        Double(index) * (bit + gap) + (bit - size) / 2
    }

    /// Computes metrics from the token formulas. `isNarrow` defaults to the `breakpoints.narrow` rule.
    public static func compute(width: Double, height: Double, columns: Int, tokens: Tokens, isNarrow: Bool? = nil) throws -> LayoutMetrics {
        let narrow = isNarrow ?? (width <= tokens.narrowBreakpoint)
        var env = ExpressionEnvironment(width: width, height: height)
        env.fontSize = try tokens.type.base.evaluate(in: env)
        let pad = try tokens.space.pad.evaluate(in: env)
        let gap = try tokens.space.gap.evaluate(in: env)
        let labelColumn = try tokens.space.labelColumn.evaluate(in: env)
        let decimalColumn = try tokens.space.decimalColumn.evaluate(in: env)
        env.variables = ["pad": pad, "gap": gap, "labelCol": labelColumn, "decimalCol": decimalColumn, "w": Double(columns)]
        let bit = max(1, try (narrow ? tokens.bit.sizeNarrow : tokens.bit.sizeWide).evaluate(in: env))
        env.variables["b"] = bit
        return LayoutMetrics(
            width: width,
            height: height,
            columns: columns,
            isNarrow: narrow,
            fontSize: env.fontSize,
            pad: pad,
            gap: gap,
            labelColumn: labelColumn,
            decimalColumn: decimalColumn,
            bit: bit,
            dateBit: bit * tokens.bit.dateScale,
            offOutline: max(tokens.bit.offOutlineMinimum, bit * tokens.bit.offOutlineFactor),
            voidDot: bit * tokens.bit.voidScale,
            squareRadius: try tokens.bit.squareRadius.evaluate(in: env),
            decimalTimeSize: try (narrow ? tokens.type.decimalNarrow : tokens.type.decimalTime).evaluate(in: env),
            decimalDateSize: try (narrow ? tokens.type.decimalNarrow : tokens.type.decimalDate).evaluate(in: env),
            placeSize: try tokens.type.place.evaluate(in: env),
            readoutSize: try (narrow ? tokens.type.readoutNarrow : tokens.type.readout).evaluate(in: env),
            separatorMargin: gap * (narrow ? tokens.space.separatorMarginFactorNarrow : tokens.space.separatorMarginFactor),
            dateRowGap: gap * tokens.space.dateRowGapFactor,
            chromeGap: try tokens.space.chromeGap.evaluate(in: env)
        )
    }
}
