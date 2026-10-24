import Foundation

public enum TokensError: Error, Equatable {
    case notAnObject
    case missing(String)
    case wrongType(String)
    case unparseable(String, String)
}

/// Decoded `design/tokens.json`. Formula strings become `TokenExpression`s; a few prose fields
/// (`separatorMargin`, `bit.states`, `motion.*`) are read with narrow regular expressions, and
/// `Tokens.load` throws if the text no longer matches, so the JSON stays the single source of truth.
public struct Tokens: Equatable, Sendable {
    public struct Opacity: Equatable, Sendable {
        public var full: Double, mid: Double, low: Double, ghost: Double, rule: Double
    }

    public struct TextStyle: Equatable, Sendable {
        public var size: TokenExpression
        public var weight: Int?
        /// Letter spacing in em (0 when the token omits it).
        public var tracking: Double
        public var uppercase: Bool
        public var opacity: Double
    }

    public struct TypeScale: Equatable, Sendable {
        public var base: TokenExpression
        public var kicker: TextStyle
        public var value: TextStyle
        public var note: TextStyle
        public var rowLabel: TextStyle
        public var rowLabelWeightDate: Int
        public var rowLabelWeightTime: Int
        public var rowSub: TextStyle
        public var decimalTime: TokenExpression
        public var decimalDate: TokenExpression
        public var decimalNarrow: TokenExpression
        public var decimalWeightTime: Int
        public var decimalWeightDate: Int
        public var place: TokenExpression
        public var placeOpacity: Double
        public var separator: TextStyle
        public var readout: TokenExpression
        public var readoutNarrow: TokenExpression
        public var readoutWeight: Int
        public var readoutTracking: Double
        public var button: TextStyle
    }

    public struct Space: Equatable, Sendable {
        public var pad: TokenExpression
        public var gap: TokenExpression
        public var labelColumn: TokenExpression
        public var decimalColumn: TokenExpression
        public var separatorMarginFactor: Double
        public var separatorMarginFactorNarrow: Double
        public var dateRowGapFactor: Double
        public var chromeGap: TokenExpression
    }

    public struct Bit: Equatable, Sendable {
        public var sizeWide: TokenExpression
        public var sizeNarrow: TokenExpression
        public var dateScale: Double
        /// Outline of an off bit as a fraction of `b`, with a 1 px floor.
        public var offOutlineFactor: Double
        public var offOutlineMinimum: Double
        /// Void dot as a fraction of `b`.
        public var voidScale: Double
        public var squareRadius: TokenExpression
    }

    public struct Motion: Equatable, Sendable {
        public var bit: TimeInterval
        public var theme: TimeInterval
        public var control: TimeInterval
        public var locationPulse: TimeInterval
        public var pulseMinimumOpacity: Double
    }

    public struct Button: Equatable, Sendable {
        public var minHeight: Double
        public var paddingX: Double
        public var gap: Double
        public var opacityRest: Double
        public var opacityHover: Double
    }

    public var version: String
    public var ink: String
    public var paper: String
    public var opacity: Opacity
    public var fontStack: [String]
    public var fontWeights: [String: Int]
    public var type: TypeScale
    public var space: Space
    public var bit: Bit
    public var motion: Motion
    public var button: Button
    public var narrowBreakpoint: Double

    public func opacity(named name: String) -> Double {
        switch name {
        case "full": return opacity.full
        case "mid": return opacity.mid
        case "low": return opacity.low
        case "ghost": return opacity.ghost
        case "rule": return opacity.rule
        default: return opacity.full
        }
    }

    // MARK: Loading

    public static func load(from data: Data) throws -> Tokens {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TokensError.notAnObject }
        let root = JSONNode(object, path: "")
        let opacity = Opacity(
            full: try root["opacity"]["full"]["value"].double(),
            mid: try root["opacity"]["mid"]["value"].double(),
            low: try root["opacity"]["low"]["value"].double(),
            ghost: try root["opacity"]["ghost"]["value"].double(),
            rule: try root["opacity"]["rule"]["value"].double()
        )
        let tokens = Tokens(
            version: try root["version"].string(),
            ink: try root["color"]["ink"].string(),
            paper: try root["color"]["paper"].string(),
            opacity: opacity,
            fontStack: try root["font"]["stack"].stringArray(),
            fontWeights: try root["font"]["weights"].intDictionary(),
            type: try typeScale(root["type"], opacity: opacity),
            space: try space(root["space"]),
            bit: try bit(root["bit"]),
            motion: try motion(root["motion"]),
            button: try button(root["button"], opacity: opacity),
            narrowBreakpoint: try firstNumber(in: root["breakpoints"]["narrow"].string(), path: "breakpoints.narrow")
        )
        return tokens
    }

    static func textStyle(_ node: JSONNode, opacity: Opacity, defaultOpacity: Double = 1) throws -> TextStyle {
        TextStyle(
            size: try node["size"].expression(),
            weight: node["weight"].optionalInt,
            tracking: try node["tracking"].optionalString.map { try emValue($0, path: node.path + ".tracking") } ?? 0,
            uppercase: node["case"].optionalString == "upper",
            opacity: node["opacity"].optionalString.map { Tokens.opacityValue($0, in: opacity) } ?? defaultOpacity
        )
    }

    static func opacityValue(_ name: String, in opacity: Opacity) -> Double {
        switch name {
        case "full": return opacity.full
        case "mid": return opacity.mid
        case "low": return opacity.low
        case "ghost": return opacity.ghost
        case "rule": return opacity.rule
        default: return 1
        }
    }

    static func typeScale(_ node: JSONNode, opacity: Opacity) throws -> TypeScale {
        let decimal = node["decimal"]
        let readout = node["readout"]
        let place = node["place"]
        return TypeScale(
            base: try node["base"]["size"].expression(),
            kicker: try textStyle(node["kicker"], opacity: opacity),
            value: try textStyle(node["value"], opacity: opacity),
            note: try textStyle(node["note"], opacity: opacity),
            rowLabel: try textStyle(node["rowLabel"], opacity: opacity),
            rowLabelWeightDate: try node["rowLabel"]["weight"]["date"].int(),
            rowLabelWeightTime: try node["rowLabel"]["weight"]["time"].int(),
            rowSub: try textStyle(node["rowSub"], opacity: opacity),
            decimalTime: try decimal["size"]["time"].expression(),
            decimalDate: try decimal["size"]["date"].expression(),
            decimalNarrow: try decimal["size"]["narrow"].expression(),
            decimalWeightTime: try decimal["weight"]["time"].int(),
            decimalWeightDate: try decimal["weight"]["date"].int(),
            place: try place["size"].expression(),
            placeOpacity: place["opacity"].optionalString.map { opacityValue($0, in: opacity) } ?? 1,
            separator: try textStyle(node["separator"], opacity: opacity),
            readout: try readout["size"].expression(),
            readoutNarrow: try readout["narrow"].expression(),
            readoutWeight: try readout["weight"].int(),
            readoutTracking: try emValue(readout["tracking"].string(), path: readout.path + ".tracking"),
            button: try textStyle(node["button"], opacity: opacity)
        )
    }

    static func space(_ node: JSONNode) throws -> Space {
        let separator = try node["separatorMargin"].string()
        let factors = numbers(in: separator)
        guard factors.count >= 2 else { throw TokensError.unparseable(node.path + ".separatorMargin", separator) }
        let dateRowGap = try node["dateRowGap"].string()
        guard let dateRowGapFactor = numbers(in: dateRowGap).first else { throw TokensError.unparseable(node.path + ".dateRowGap", dateRowGap) }
        return Space(
            pad: try node["pad"].expression(),
            gap: try node["gap"].expression(),
            labelColumn: try node["labelCol"].expression(),
            decimalColumn: try node["decimalCol"].expression(),
            separatorMarginFactor: factors[0],
            separatorMarginFactorNarrow: factors[1],
            dateRowGapFactor: dateRowGapFactor,
            chromeGap: try node["chromeGap"].expression()
        )
    }

    static func bit(_ node: JSONNode) throws -> Bit {
        let off = try node["states"]["off"].string()
        // "outline max(1px, b * 0.055) fg at opacity.low"
        guard let outlineRange = off.range(of: #"max\(([0-9.]+)px,\s*b\s*\*\s*([0-9.]+)\)"#, options: .regularExpression) else {
            throw TokensError.unparseable(node.path + ".states.off", off)
        }
        let outlineNumbers = numbers(in: String(off[outlineRange]))
        guard outlineNumbers.count == 2 else { throw TokensError.unparseable(node.path + ".states.off", off) }
        let void = try node["states"]["void"].string()
        // "dot fg at opacity.ghost, scale 0.1"
        guard let scaleRange = void.range(of: #"scale\s+([0-9.]+)"#, options: .regularExpression),
              let voidScale = numbers(in: String(void[scaleRange])).first
        else { throw TokensError.unparseable(node.path + ".states.void", void) }
        return Bit(
            sizeWide: try node["size"]["wide"].expression(),
            sizeNarrow: try node["size"]["narrow"].expression(),
            dateScale: try node["dateScale"].double(),
            offOutlineFactor: outlineNumbers[1],
            offOutlineMinimum: outlineNumbers[0],
            voidScale: voidScale,
            squareRadius: try node["shape"]["square"].expression()
        )
    }

    static func motion(_ node: JSONNode) throws -> Motion {
        let pulse = try node["locationPulse"].string()
        let pulseNumbers = numbers(in: pulse.replacingOccurrences(of: "ease-in-out", with: ""))
        return Motion(
            bit: try duration(in: node["bit"].string(), path: node.path + ".bit"),
            theme: try duration(in: node["theme"].string(), path: node.path + ".theme"),
            control: try duration(in: node["control"].string(), path: node.path + ".control"),
            locationPulse: try duration(in: pulse, path: node.path + ".locationPulse"),
            pulseMinimumOpacity: pulseNumbers.last ?? 0.2
        )
    }

    static func button(_ node: JSONNode, opacity: Opacity) throws -> Button {
        Button(
            minHeight: try firstNumber(in: node["minHeight"].string(), path: node.path + ".minHeight"),
            paddingX: try firstNumber(in: node["paddingX"].string(), path: node.path + ".paddingX"),
            gap: try firstNumber(in: node["gap"].string(), path: node.path + ".gap"),
            opacityRest: opacityValue(try node["opacityRest"].string(), in: opacity),
            opacityHover: opacityValue(try node["opacityHover"].string(), in: opacity)
        )
    }

    // MARK: Prose readers

    /// All decimal numbers in `text`, in order.
    static func numbers(in text: String) -> [Double] {
        var result: [Double] = []
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil
        while !scanner.isAtEnd {
            if let value = scanner.scanDouble() {
                result.append(value)
            } else {
                _ = scanner.scanCharacter()
            }
        }
        return result
    }

    static func firstNumber(in text: String, path: String) throws -> Double {
        guard let n = numbers(in: text).first else { throw TokensError.unparseable(path, text) }
        return n
    }

    /// First `<n>ms` or `<n>s` in `text`, in seconds.
    static func duration(in text: String, path: String) throws -> TimeInterval {
        if let range = text.range(of: #"([0-9.]+)\s*ms"#, options: .regularExpression),
           let n = numbers(in: String(text[range])).first {
            return n / 1000
        }
        if let range = text.range(of: #"([0-9.]+)\s*s"#, options: .regularExpression),
           let n = numbers(in: String(text[range])).first {
            return n
        }
        throw TokensError.unparseable(path, text)
    }

    /// `"0.18em"` → 0.18.
    static func emValue(_ text: String, path: String) throws -> Double {
        guard text.hasSuffix("em"), let n = Double(text.dropLast(2)) else { throw TokensError.unparseable(path, text) }
        return n
    }
}

/// Minimal typed accessor over `JSONSerialization` output with a readable path in errors.
struct JSONNode {
    let value: Any?
    let path: String

    init(_ value: Any?, path: String) {
        self.value = value
        self.path = path
    }

    subscript(key: String) -> JSONNode {
        let child = (value as? [String: Any])?[key]
        return JSONNode(child, path: path.isEmpty ? key : path + "." + key)
    }

    var optionalString: String? { value as? String }
    var optionalInt: Int? { (value as? NSNumber)?.intValue }

    func string() throws -> String {
        guard value != nil else { throw TokensError.missing(path) }
        guard let s = value as? String else { throw TokensError.wrongType(path) }
        return s
    }

    func double() throws -> Double {
        guard value != nil else { throw TokensError.missing(path) }
        guard let n = value as? NSNumber else { throw TokensError.wrongType(path) }
        return n.doubleValue
    }

    func int() throws -> Int {
        guard value != nil else { throw TokensError.missing(path) }
        guard let n = value as? NSNumber else { throw TokensError.wrongType(path) }
        return n.intValue
    }

    func stringArray() throws -> [String] {
        guard value != nil else { throw TokensError.missing(path) }
        guard let a = value as? [String] else { throw TokensError.wrongType(path) }
        return a
    }

    func intDictionary() throws -> [String: Int] {
        guard value != nil else { throw TokensError.missing(path) }
        guard let d = value as? [String: NSNumber] else { throw TokensError.wrongType(path) }
        return d.mapValues { $0.intValue }
    }

    func expression() throws -> TokenExpression {
        let text = try string()
        do { return try TokenExpression(text) } catch { throw TokensError.unparseable(path, text) }
    }
}
