import Foundation

/// Inputs for evaluating a token formula: the container size (for `cqmin`/`cqw`/`cqh`),
/// the current font size (for `em`) and named lengths such as `pad`, `gap`, `labelCol`, `w`, `b`.
public struct ExpressionEnvironment: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var fontSize: Double
    public var variables: [String: Double]

    public init(width: Double, height: Double, fontSize: Double = 16, variables: [String: Double] = [:]) {
        self.width = width
        self.height = height
        self.fontSize = fontSize
        self.variables = variables
    }
}

public enum TokenExpressionError: Error, Equatable {
    case unexpectedCharacter(Character, offset: Int)
    case unexpectedEnd
    case unexpectedToken(String)
    case unknownFunction(String)
    case unknownUnit(String)
    case unknownVariable(String)
    case wrongArity(String, expected: Int, got: Int)
}

/// A parsed CSS-like length formula from `tokens.json`, e.g. `clamp(16px, 4.2cqmin, 64px)` or
/// `min((100cqw - 2*pad - labelCol - decimalCol - (w + 1)*gap) / w, (100cqh - 2*pad - 30cqh) / 10.4, 116px)`.
///
/// Grammar: `+ - * /`, parentheses, unary minus, numbers with optional unit
/// (`px`, `em`, `cqmin`, `cqw`, `cqh`, unitless), identifiers, and `clamp(min, val, max)`, `min(...)`, `max(...)`.
public struct TokenExpression: Equatable, Sendable, CustomStringConvertible {
    public let source: String
    let root: Node

    public init(_ source: String) throws {
        self.source = source
        var parser = Parser(tokens: try Lexer.tokenize(source))
        root = try parser.parseExpression()
        guard parser.atEnd else { throw TokenExpressionError.unexpectedToken(parser.describeCurrent()) }
    }

    public var description: String { source }

    public func evaluate(in env: ExpressionEnvironment) throws -> Double {
        try root.evaluate(in: env)
    }

    public static func == (lhs: TokenExpression, rhs: TokenExpression) -> Bool { lhs.source == rhs.source }

    // MARK: AST

    indirect enum Node: Sendable {
        case number(Double, unit: String?)
        case variable(String)
        case negate(Node)
        case binary(Character, Node, Node)
        case call(String, [Node])

        func evaluate(in env: ExpressionEnvironment) throws -> Double {
            switch self {
            case .number(let value, let unit):
                return try value * Node.unitScale(unit, env: env)
            case .variable(let name):
                guard let v = env.variables[name] else { throw TokenExpressionError.unknownVariable(name) }
                return v
            case .negate(let inner):
                return try -inner.evaluate(in: env)
            case .binary(let op, let l, let r):
                let a = try l.evaluate(in: env), b = try r.evaluate(in: env)
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                default: return b == 0 ? .infinity : a / b
                }
            case .call(let name, let args):
                let values = try args.map { try $0.evaluate(in: env) }
                switch name {
                case "clamp":
                    guard values.count == 3 else { throw TokenExpressionError.wrongArity(name, expected: 3, got: values.count) }
                    // CSS semantics: max(min, min(val, max)); when min > max, min wins.
                    return Swift.max(values[0], Swift.min(values[1], values[2]))
                case "min":
                    guard let m = values.min() else { throw TokenExpressionError.wrongArity(name, expected: 1, got: 0) }
                    return m
                case "max":
                    guard let m = values.max() else { throw TokenExpressionError.wrongArity(name, expected: 1, got: 0) }
                    return m
                default:
                    throw TokenExpressionError.unknownFunction(name)
                }
            }
        }

        static func unitScale(_ unit: String?, env: ExpressionEnvironment) throws -> Double {
            switch unit {
            case nil, "px": return 1
            case "em": return env.fontSize
            case "cqmin": return Swift.min(env.width, env.height) / 100
            case "cqw": return env.width / 100
            case "cqh": return env.height / 100
            case "%": return 0.01
            case let u?: throw TokenExpressionError.unknownUnit(u)
            }
        }
    }

    // MARK: Lexer

    enum Token: Equatable {
        case number(Double, unit: String?)
        case identifier(String)
        case symbol(Character)
    }

    enum Lexer {
        static func tokenize(_ text: String) throws -> [Token] {
            var tokens: [Token] = []
            let chars = Array(text)
            var i = 0
            while i < chars.count {
                let c = chars[i]
                if c.isWhitespace { i += 1; continue }
                if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                    var j = i
                    while j < chars.count, chars[j].isNumber || chars[j] == "." { j += 1 }
                    let value = Double(String(chars[i..<j])) ?? 0
                    var k = j
                    while k < chars.count, chars[k].isLetter || chars[k] == "%" { k += 1 }
                    let unit = k > j ? String(chars[j..<k]) : nil
                    tokens.append(.number(value, unit: unit))
                    i = k
                    continue
                }
                if c.isLetter || c == "_" {
                    var j = i
                    while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                    tokens.append(.identifier(String(chars[i..<j])))
                    i = j
                    continue
                }
                if "+-*/(),".contains(c) {
                    tokens.append(.symbol(c))
                    i += 1
                    continue
                }
                throw TokenExpressionError.unexpectedCharacter(c, offset: i)
            }
            return tokens
        }
    }

    // MARK: Parser (recursive descent)

    struct Parser {
        var tokens: [Token]
        var index = 0

        init(tokens: [Token]) { self.tokens = tokens }

        var atEnd: Bool { index >= tokens.count }
        var current: Token? { atEnd ? nil : tokens[index] }

        func describeCurrent() -> String {
            guard let current else { return "end" }
            return "\(current)"
        }

        mutating func parseExpression() throws -> Node {
            var node = try parseTerm()
            while case .symbol(let op)? = current, op == "+" || op == "-" {
                index += 1
                node = .binary(op, node, try parseTerm())
            }
            return node
        }

        mutating func parseTerm() throws -> Node {
            var node = try parseUnary()
            while case .symbol(let op)? = current, op == "*" || op == "/" {
                index += 1
                node = .binary(op, node, try parseUnary())
            }
            return node
        }

        mutating func parseUnary() throws -> Node {
            if case .symbol("-")? = current {
                index += 1
                return .negate(try parseUnary())
            }
            if case .symbol("+")? = current {
                index += 1
                return try parseUnary()
            }
            return try parsePrimary()
        }

        mutating func parsePrimary() throws -> Node {
            guard let token = current else { throw TokenExpressionError.unexpectedEnd }
            index += 1
            switch token {
            case .number(let value, let unit):
                return .number(value, unit: unit)
            case .identifier(let name):
                if case .symbol("(")? = current {
                    index += 1
                    var args: [Node] = []
                    if case .symbol(")")? = current {
                        index += 1
                        return .call(name, args)
                    }
                    while true {
                        args.append(try parseExpression())
                        guard let next = current else { throw TokenExpressionError.unexpectedEnd }
                        index += 1
                        if next == .symbol(")") { break }
                        guard next == .symbol(",") else { throw TokenExpressionError.unexpectedToken("\(next)") }
                    }
                    return .call(name, args)
                }
                return .variable(name)
            case .symbol("("):
                let inner = try parseExpression()
                guard current == .symbol(")") else { throw TokenExpressionError.unexpectedToken(describeCurrent()) }
                index += 1
                return inner
            case .symbol(let s):
                throw TokenExpressionError.unexpectedToken(String(s))
            }
        }
    }
}
