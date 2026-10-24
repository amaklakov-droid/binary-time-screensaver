import Foundation

/// The six UI languages, in switcher order (SPEC §5).
public enum Language: String, CaseIterable, Codable, Sendable {
    case en, ru, he, ar, bo, ja

    /// First supported language in `preferred` (BCP 47 tags, e.g. `["en-RU", "ru-RU"]`); `iw` maps to `he`.
    public static func resolveDefault(preferred: [String], fallback: Language = .en) -> Language {
        for tag in preferred {
            let code = tag.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
            if code == "iw" { return .he }
            if let lang = Language(rawValue: code) { return lang }
        }
        return fallback
    }

    /// Next language in switcher order (wraps).
    public var next: Language {
        let all = Language.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

public enum TextDirection: String, Codable, Sendable { case ltr, rtl }

public enum DigitSet: String, Codable, Sendable { case latn, arab, tibt }

public enum Digits {
    /// Replaces ASCII digits with the ten characters of `set` (a 10-character string).
    public static func map(_ text: String, to set: String) -> String {
        let glyphs = Array(set)
        guard glyphs.count == 10 else { return text }
        var out = String()
        out.reserveCapacity(text.utf16.count)
        for ch in text {
            if let ascii = ch.asciiValue, ascii >= 48, ascii <= 57 {
                out.append(glyphs[Int(ascii - 48)])
            } else {
                out.append(ch)
            }
        }
        return out
    }
}
