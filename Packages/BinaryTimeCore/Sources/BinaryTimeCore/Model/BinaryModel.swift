import Foundation

/// Visual state of one cell in a bit grid (SPEC §3, tokens `bit.states`).
public enum BitState: Equatable, Sendable {
    /// Bit is 1 — filled.
    case on
    /// Bit is 0 — outline.
    case off
    /// Position the metric does not use — tiny dot, keeps place values aligned.
    case void
}

/// The six displayed quantities, in row order (SPEC §2.2).
public enum Metric: Int, CaseIterable, Sendable {
    case year = 0, month, day, hours, minutes, seconds

    /// Rows of the «date» group are rendered at 0.56 × b and 66 % opacity.
    public var isDate: Bool { rawValue < 3 }
}

/// Pure binary arithmetic shared by every row (SPEC §2.1–2.2).
public enum BinaryModel {
    public static let minColumns = 7
    public static let maxColumns = 14

    /// Number of binary digits needed for `value`; 0 and negatives count as one digit.
    public static func bitLength(_ value: Int) -> Int {
        guard value > 0 else { return 1 }
        return Int.bitWidth - value.leadingZeroBitCount
    }

    /// Shared column count `w = clamp(bitLength(year), 7, 14)`.
    public static func columns(forYear year: Int) -> Int {
        min(maxColumns, max(minColumns, bitLength(year)))
    }

    /// Place values `2ⁿ` for the header row, most significant first.
    public static func placeValues(columns: Int) -> [Int] {
        (0..<columns).reversed().map { 1 << $0 }
    }

    /// Cell states for one row, most significant bit on the left, right-aligned in `columns`.
    /// Positions at or above `bits` are `.void`.
    public static func states(value: Int, bits: Int, columns: Int) -> [BitState] {
        (0..<columns).reversed().map { position in
            if position >= bits { return .void }
            return (value >> position) & 1 == 1 ? .on : .off
        }
    }

    /// Zero-padded binary string, e.g. `binaryString(12, bits: 4) == "1100"`.
    public static func binaryString(_ value: Int, bits: Int) -> String {
        let raw = String(max(0, value), radix: 2)
        return String(repeating: "0", count: max(0, bits - raw.count)) + raw
    }
}
