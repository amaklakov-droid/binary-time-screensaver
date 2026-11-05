import AppKit
import BinaryTimeCore

/// Every drawable thing on the screen. Rows and bits are keyed by metric and column.
public enum SceneElement: Hashable {
    case title, calendarLine, dateLine
    case locationTag, locationL1, locationL2, locationL3, pulse
    case placeLabel, placeValue(Int)
    case rowLabel(Metric), rowSub(Metric), rowDecimal(Metric)
    case bit(Metric, Int)
    case separatorLabel, separatorRule
    case readout, dayPeriod, legendDotOn, legendOne, legendDotOff, legendZero, legendOffset
}

public struct TextPlacement: Equatable {
    /// Top-left-origin frame (CSS-like); the scene converts to Core Animation's y-up space.
    public var frame: CGRect
    public var style: TextStyle
    public var alignment: TextAlignment
    /// Base writing direction for bidi resolution (see `SceneLayout.direction(of:in:)`).
    public var direction: TextDirection = .ltr
}

/// The computed geometry for one model, size and metrics.
public struct SceneFrames: Equatable {
    public var size: CGSize
    public var isNarrow: Bool
    public var texts: [SceneElement: TextPlacement] = [:]
    /// Pulse dot, separator rule, legend glyphs and every bit cell.
    public var shapes: [SceneElement: CGRect] = [:]
    public var bitSize: [Metric: CGFloat] = [:]
    /// Where the host places its control pills (top-left origin); `.zero` when none.
    public var controls: CGRect = .zero
    /// True when the bit block does not fit vertically (tokens should prevent this).
    public var overflows = false
}

extension SceneLayout {
    /// Writing direction per element, mirroring the prototype's CSS: the readout, legend and place values are
    /// `dir="ltr"`; header values and notes use `unicode-bidi: plaintext` (first strong character decides,
    /// Latin when there is none); everything else inherits the language direction.
    public static func direction(of element: SceneElement, in model: ScreenModel) -> TextDirection {
        switch element {
        case .readout, .dayPeriod, .legendOne, .legendZero, .legendOffset, .placeValue, .placeLabel:
            return .ltr
        case .calendarLine, .dateLine, .locationL1, .locationL2, .locationL3:
            return plaintextDirection(of: ClockScene.text(for: element, in: model))
        default:
            return model.direction
        }
    }

    /// Unicode bidi P2/P3: the first strong character sets the paragraph direction; none → LTR.
    public static func plaintextDirection(of text: String) -> TextDirection {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x0590...0x08FF).contains(v) || (0xFB1D...0xFDFF).contains(v) || (0xFE70...0xFEFF).contains(v) {
                return .rtl
            }
            if scalar.properties.isAlphabetic {
                return .ltr
            }
        }
        return .ltr
    }
}

public struct FittedLayout {
    public var frames: SceneFrames
    public var metrics: LayoutMetrics
    /// Virtual-to-actual scale: 1 for a native layout, > 1 when a miniature is drawn (previews, tiny windows).
    public var scale: CGFloat
    public var virtualSize: CGSize { frames.size }
}

extension SceneLayout {
    /// Short side of the virtual screen used when the native layout cannot fit (MACOS.md §2.4: previews).
    public static let miniatureShortSide: CGFloat = 900

    /// Lays out natively; if the bit block overflows, lays out a `miniatureShortSide` virtual screen with the
    /// same aspect ratio instead and reports the scale to draw it at.
    public static func fit(model: ScreenModel, tokens: Tokens, fonts: FontRegistry, size: CGSize,
                           controlsSize: (CGFloat, LayoutMetrics) -> CGSize?) throws -> FittedLayout {
        let native = try LayoutMetrics.compute(width: size.width, height: size.height, columns: model.columns, tokens: tokens)
        let nativeFrames = compute(model: model, metrics: native, tokens: tokens, fonts: fonts, size: size, controlsSize: controlsSize)
        let shortSide = min(size.width, size.height)
        guard nativeFrames.overflows, shortSide > 0, shortSide < miniatureShortSide else {
            return FittedLayout(frames: nativeFrames, metrics: native, scale: 1)
        }
        let k = miniatureShortSide / shortSide
        let virtual = CGSize(width: size.width * k, height: size.height * k)
        let metrics = try LayoutMetrics.compute(width: virtual.width, height: virtual.height, columns: model.columns, tokens: tokens)
        // A miniature has no room for real controls; the host hides them.
        let frames = compute(model: model, metrics: metrics, tokens: tokens, fonts: fonts, size: virtual, controlsSize: { _, _ in nil })
        return FittedLayout(frames: frames, metrics: metrics, scale: k)
    }
}

/// SPEC §2 composition in code: header and footer span the width, the bit block is one centred column,
/// RTL mirrors label/decimal sides while the grid stays LTR, and the narrow layout stacks everything.
public enum SceneLayout {
    public static func compute(model: ScreenModel,
                               metrics: LayoutMetrics,
                               tokens: Tokens,
                               fonts: FontRegistry,
                               size: CGSize,
                               controlsSize: (CGFloat, LayoutMetrics) -> CGSize?) -> SceneFrames {
        let W = size.width, H = size.height
        let fs = CGFloat(metrics.fontSize)
        let pad = CGFloat(metrics.pad)
        let gap = CGFloat(metrics.gap)
        let rtl = model.direction == .rtl
        let narrow = metrics.isNarrow
        let sheet = StyleSheet(tokens: tokens, fonts: fonts, metrics: metrics, caps: model.caps, lineHeightMultiple: model.lineHeight)
        var frames = SceneFrames(size: size, isNarrow: narrow)
        let startAlign: TextAlignment = rtl ? .right : .left
        let endAlign: TextAlignment = rtl ? .left : .right
        let contentW = W - 2 * pad

        func put(_ element: SceneElement, _ frame: CGRect, _ style: TextStyle, _ alignment: TextAlignment) {
            frames.texts[element] = TextPlacement(frame: frame, style: style, alignment: alignment,
                                                  direction: SceneLayout.direction(of: element, in: model))
        }

        // MARK: Header
        let kicker = sheet.kicker, value = sheet.value, note = sheet.note
        let lineGap = PrototypeStyle.blockLineGapEm * fs
        typealias Line = (element: SceneElement, text: String, style: TextStyle)
        let titleLines: [Line] = [(.title, model.header.title, kicker),
                                  (.calendarLine, model.header.calendarLine, value),
                                  (.dateLine, model.header.dateLine, note)]
        var locationLines: [Line] = [(.locationTag, model.location.tag, kicker),
                                     (.locationL1, model.location.l1, value),
                                     (.locationL2, model.location.l2, note)]
        if !model.location.l3.isEmpty { locationLines.append((.locationL3, model.location.l3, note)) }
        func blockHeight(_ lines: [Line]) -> CGFloat {
            lines.reduce(0) { $0 + $1.style.lineHeight } + CGFloat(max(0, lines.count - 1)) * lineGap
        }
        let titleH = blockHeight(titleLines), locationH = blockHeight(locationLines)
        let titleBlock: CGRect, locationBlock: CGRect
        let titleAlign: TextAlignment, locationAlign: TextAlignment
        let headerH: CGFloat
        if narrow {
            titleBlock = CGRect(x: pad, y: pad, width: contentW, height: titleH)
            locationBlock = CGRect(x: pad, y: pad + titleH + PrototypeStyle.narrowHeaderGap, width: contentW, height: locationH)
            titleAlign = startAlign
            locationAlign = startAlign
            headerH = titleH + PrototypeStyle.narrowHeaderGap + locationH
        } else {
            let chrome = CGFloat(metrics.chromeGap)
            let halfW = (contentW - chrome) / 2
            let startX = pad, endX = pad + halfW + chrome
            titleBlock = CGRect(x: rtl ? endX : startX, y: pad, width: halfW, height: titleH)
            locationBlock = CGRect(x: rtl ? startX : endX, y: pad, width: halfW, height: locationH)
            titleAlign = startAlign
            locationAlign = endAlign
            headerH = max(titleH, locationH)
        }

        func layoutTagLine(_ line: Line, at y: CGFloat, in block: CGRect, align: TextAlignment) {
            let dot = PrototypeStyle.pulseSizeEm * line.style.font.pointSize
            let dotGap = PrototypeStyle.pulseGapEm * line.style.font.pointSize
            let textW = line.style.width(of: line.text)
            let boxW = dot + dotGap + textW
            let boxX: CGFloat
            switch align {
            case .left: boxX = block.minX
            case .right: boxX = block.maxX - boxW
            case .center: boxX = block.midX - boxW / 2
            }
            let lh = line.style.lineHeight
            let dotRect: CGRect, textX: CGFloat
            if rtl {
                textX = boxX
                dotRect = CGRect(x: boxX + textW + dotGap, y: y + (lh - dot) / 2, width: dot, height: dot)
            } else {
                dotRect = CGRect(x: boxX, y: y + (lh - dot) / 2, width: dot, height: dot)
                textX = boxX + dot + dotGap
            }
            frames.shapes[.pulse] = dotRect
            put(line.element, CGRect(x: textX, y: y, width: textW + 1, height: lh), line.style, .left)
        }

        func layoutBlock(_ lines: [Line], in block: CGRect, align: TextAlignment) {
            var y = block.minY
            for line in lines {
                if line.element == .locationTag {
                    layoutTagLine(line, at: y, in: block, align: align)
                } else {
                    put(line.element, CGRect(x: block.minX, y: y, width: block.width, height: line.style.lineHeight), line.style, align)
                }
                y += line.style.lineHeight + lineGap
            }
        }
        layoutBlock(titleLines, in: titleBlock, align: titleAlign)
        layoutBlock(locationLines, in: locationBlock, align: locationAlign)

        // MARK: Footer
        let readoutStyle = sheet.readout, periodStyle = sheet.dayPeriod, legendStyle = sheet.legend
        let legendFont = legendStyle.font.pointSize
        let legendMargin = PrototypeStyle.legendMarginTopEm * legendFont
        let readoutLineH = max(readoutStyle.lineHeight, periodStyle.lineHeight)
        let footerBlockH = readoutLineH + legendMargin + legendStyle.lineHeight
        let readoutW = readoutStyle.width(of: model.footer.readout)
        let periodW = model.footer.dayPeriod.isEmpty ? 0 : periodStyle.width(of: model.footer.dayPeriod)
        let periodMargin = PrototypeStyle.dayPeriodMarginEm * periodStyle.font.pointSize
        let groupW = readoutW + (periodW > 0 ? periodMargin + periodW : 0)
        let glyph = PrototypeStyle.legendGlyphEm * legendFont
        let glyphGap = PrototypeStyle.legendGlyphGapEm * legendFont
        let itemGap = PrototypeStyle.legendItemGapEm * legendFont
        let legendItems: [(dot: SceneElement?, text: SceneElement, value: String)] = [
            (.legendDotOn, .legendOne, "1"),
            (.legendDotOff, .legendZero, "0"),
            (nil, .legendOffset, model.footer.utcOffset),
        ]
        let legendW = legendItems.reduce(0) { $0 + ($1.dot == nil ? 0 : glyph + glyphGap) + legendStyle.width(of: $1.value) } + CGFloat(legendItems.count - 1) * itemGap
        let footerBlockW = max(groupW, legendW)
        // Controls take the width left beside the readout block (CSS `.bt-bottom` flex row); narrow: a row of their own.
        let controls = controlsSize(narrow ? contentW : max(0, contentW - footerBlockW - CGFloat(metrics.chromeGap)), metrics)
        var footerH = footerBlockH
        if let c = controls {
            if narrow {
                footerH = footerBlockH + CGFloat(metrics.chromeGap) + c.height
                frames.controls = CGRect(x: pad, y: H - pad - c.height, width: min(c.width, contentW), height: c.height)
            } else {
                footerH = max(footerBlockH, c.height)
                frames.controls = CGRect(x: rtl ? pad : W - pad - c.width, y: H - pad - c.height, width: c.width, height: c.height)
            }
        }
        let footerTop = H - pad - footerH
        let blockTop = (narrow && controls != nil) ? footerTop : H - pad - footerBlockH
        let groupX = rtl ? W - pad - groupW : pad
        let readoutBaseline = blockTop + (readoutLineH - readoutStyle.lineHeight) / 2 + readoutStyle.baselineFromTop
        put(.readout, CGRect(x: groupX, y: readoutStyle.frameTop(forBaseline: readoutBaseline), width: readoutW + 1, height: readoutStyle.lineHeight), readoutStyle, .left)
        if periodW > 0 {
            put(.dayPeriod, CGRect(x: groupX + readoutW + periodMargin, y: periodStyle.frameTop(forBaseline: readoutBaseline), width: periodW + 1, height: periodStyle.lineHeight), periodStyle, .left)
        }
        let legendY = blockTop + readoutLineH + legendMargin
        var cursor = rtl ? W - pad : pad
        for item in legendItems {
            let textW = legendStyle.width(of: item.value)
            let itemW = (item.dot == nil ? 0 : glyph + glyphGap) + textW
            let dotY = legendY + (legendStyle.lineHeight - glyph) / 2
            if rtl {
                let right = cursor
                if let dot = item.dot {
                    frames.shapes[dot] = CGRect(x: right - glyph, y: dotY, width: glyph, height: glyph)
                    put(item.text, CGRect(x: right - glyph - glyphGap - textW, y: legendY, width: textW + 1, height: legendStyle.lineHeight), legendStyle, .left)
                } else {
                    put(item.text, CGRect(x: right - textW, y: legendY, width: textW + 1, height: legendStyle.lineHeight), legendStyle, .left)
                }
                cursor -= itemW + itemGap
            } else {
                var x = cursor
                if let dot = item.dot {
                    frames.shapes[dot] = CGRect(x: x, y: dotY, width: glyph, height: glyph)
                    x += glyph + glyphGap
                }
                put(item.text, CGRect(x: x, y: legendY, width: textW + 1, height: legendStyle.lineHeight), legendStyle, .left)
                cursor += itemW + itemGap
            }
        }

        // MARK: Bit block
        let mainTop = pad + headerH + gap
        let mainBottom = footerTop - gap
        let mainH = mainBottom - mainTop
        let b = CGFloat(metrics.bit), db = CGFloat(metrics.dateBit)
        let gridW = CGFloat(metrics.gridWidth)
        let blockW = narrow ? contentW : CGFloat(metrics.bitBlockWidth)
        let blockX = narrow ? pad : (W - blockW) / 2
        let labelDate = sheet.rowLabelDate, labelTime = sheet.rowLabelTime, subStyle = sheet.rowSub
        let decDate = sheet.decimalDate, decTime = sheet.decimalTime
        let placeStyle = sheet.place, sepStyle = sheet.separator
        let labelGap = PrototypeStyle.labelSubGapEm * labelTime.font.pointSize
        let labCol = CGFloat(metrics.labelColumn), decCol = CGFloat(metrics.decimalColumn)
        let columns = model.columns

        func labelBlockH(_ label: TextStyle) -> CGFloat { label.lineHeight + labelGap + subStyle.lineHeight }
        func narrowLineH(_ label: TextStyle, _ dec: TextStyle) -> CGFloat {
            let baseline = max(label.baselineFromTop, subStyle.baselineFromTop, dec.baselineFromTop)
            let below = max(label.lineHeight - label.baselineFromTop, subStyle.lineHeight - subStyle.baselineFromTop, dec.lineHeight - dec.baselineFromTop)
            return baseline + below
        }
        let rowHDate = narrow ? narrowLineH(labelDate, decDate) + PrototypeStyle.narrowRowGap + db : max(db, labelBlockH(labelDate))
        let rowHTime = narrow ? narrowLineH(labelTime, decTime) + PrototypeStyle.narrowRowGap + b : max(b, labelBlockH(labelTime))
        let placeRowH = narrow ? 0 : max(labelDate.lineHeight, placeStyle.lineHeight)
        let dateRowGap = CGFloat(metrics.dateRowGap)
        let sepMargin = CGFloat(metrics.separatorMargin)
        let placeBlockH = narrow ? 0 : placeRowH + gap * (1 - PrototypeStyle.placeRowOverlapFactor)
        let dateH = 3 * rowHDate + 2 * dateRowGap
        let timeH = 3 * rowHTime + 2 * gap
        let totalH = placeBlockH + dateH + gap + sepMargin + sepStyle.lineHeight + sepMargin + gap + timeH
        frames.overflows = totalH > mainH + 0.5
        var y = mainTop + max(0, (mainH - totalH) / 2)

        let labelX: CGFloat, gridX: CGFloat, decX: CGFloat
        if narrow {
            labelX = pad; gridX = pad; decX = pad
        } else if rtl {
            decX = blockX
            gridX = blockX + decCol + gap
            labelX = gridX + gridW + gap
        } else {
            labelX = blockX
            gridX = blockX + labCol + gap
            decX = gridX + gridW + gap
        }
        let labelAlign = startAlign, decAlign = endAlign

        func layoutBits(_ metric: Metric, rowY: CGFloat, rowH: CGFloat, cell: CGFloat, gridTop: CGFloat?) {
            for i in 0..<columns {
                let x = gridX + CGFloat(i) * (b + gap) + (b - cell) / 2
                let cy = gridTop ?? (rowY + (rowH - cell) / 2)
                frames.shapes[.bit(metric, i)] = CGRect(x: x, y: cy, width: cell, height: cell)
            }
            frames.bitSize[metric] = cell
        }

        func layoutRow(_ metric: Metric, rowY: CGFloat, rowH: CGFloat, cell: CGFloat, label: TextStyle, dec: TextStyle) {
            let row = model.rows[metric.rawValue]
            if narrow {
                let baseline = rowY + max(label.baselineFromTop, subStyle.baselineFromTop, dec.baselineFromTop)
                let lw = label.width(of: row.label)
                let sw = subStyle.width(of: row.sub)
                let lgap = PrototypeStyle.narrowLabelGapEm * label.font.pointSize
                if rtl {
                    put(.rowLabel(metric), CGRect(x: W - pad - lw, y: label.frameTop(forBaseline: baseline), width: lw + 1, height: label.lineHeight), label, .left)
                    put(.rowSub(metric), CGRect(x: W - pad - lw - lgap - sw, y: subStyle.frameTop(forBaseline: baseline), width: sw + 1, height: subStyle.lineHeight), subStyle, .left)
                    put(.rowDecimal(metric), CGRect(x: pad, y: dec.frameTop(forBaseline: baseline), width: contentW, height: dec.lineHeight), dec, .left)
                } else {
                    put(.rowLabel(metric), CGRect(x: pad, y: label.frameTop(forBaseline: baseline), width: lw + 1, height: label.lineHeight), label, .left)
                    put(.rowSub(metric), CGRect(x: pad + lw + lgap, y: subStyle.frameTop(forBaseline: baseline), width: sw + 1, height: subStyle.lineHeight), subStyle, .left)
                    put(.rowDecimal(metric), CGRect(x: pad, y: dec.frameTop(forBaseline: baseline), width: contentW, height: dec.lineHeight), dec, .right)
                }
                let lineH = narrowLineH(label, dec)
                layoutBits(metric, rowY: rowY, rowH: rowH, cell: cell, gridTop: rowY + lineH + PrototypeStyle.narrowRowGap)
            } else {
                let lbH = labelBlockH(label)
                let ly = rowY + (rowH - lbH) / 2
                put(.rowLabel(metric), CGRect(x: labelX, y: ly, width: labCol, height: label.lineHeight), label, labelAlign)
                put(.rowSub(metric), CGRect(x: labelX, y: ly + label.lineHeight + labelGap, width: labCol, height: subStyle.lineHeight), subStyle, labelAlign)
                put(.rowDecimal(metric), CGRect(x: decX, y: rowY + (rowH - dec.lineHeight) / 2, width: decCol, height: dec.lineHeight), dec, decAlign)
                layoutBits(metric, rowY: rowY, rowH: rowH, cell: cell, gridTop: nil)
            }
        }

        if !narrow {
            put(.placeLabel, CGRect(x: labelX, y: y, width: labCol, height: placeRowH), labelDate, labelAlign)
            for i in 0..<columns {
                put(.placeValue(i), CGRect(x: gridX + CGFloat(i) * (b + gap), y: y, width: b, height: placeRowH), placeStyle, .center)
            }
            y += placeBlockH
        }
        for (i, metric) in [Metric.year, .month, .day].enumerated() {
            if i > 0 { y += dateRowGap }
            layoutRow(metric, rowY: y, rowH: rowHDate, cell: db, label: labelDate, dec: decDate)
            y += rowHDate
        }
        y += gap + sepMargin
        let sepW = sepStyle.width(of: model.separatorLabel)
        let sepGap = PrototypeStyle.separatorGapEm * sepStyle.font.pointSize
        let ruleY = y + sepStyle.lineHeight / 2 - 0.5
        if rtl {
            put(.separatorLabel, CGRect(x: blockX + blockW - sepW, y: y, width: sepW + 1, height: sepStyle.lineHeight), sepStyle, .left)
            frames.shapes[.separatorRule] = CGRect(x: blockX, y: ruleY, width: max(0, blockW - sepW - sepGap), height: 1)
        } else {
            put(.separatorLabel, CGRect(x: blockX, y: y, width: sepW + 1, height: sepStyle.lineHeight), sepStyle, .left)
            frames.shapes[.separatorRule] = CGRect(x: blockX + sepW + sepGap, y: ruleY, width: max(0, blockW - sepW - sepGap), height: 1)
        }
        y += sepStyle.lineHeight + sepMargin + gap
        for (i, metric) in [Metric.hours, .minutes, .seconds].enumerated() {
            if i > 0 { y += gap }
            layoutRow(metric, rowY: y, rowH: rowHTime, cell: b, label: labelTime, dec: decTime)
            y += rowHTime
        }
        return frames
    }
}
