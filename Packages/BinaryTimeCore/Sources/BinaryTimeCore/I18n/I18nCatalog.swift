import Foundation

/// Per-language rules from `i18n.meta`.
public struct LanguageMeta: Codable, Equatable, Sendable {
    public var native: String
    public var dir: TextDirection
    public var digits: DigitSet
    public var font: String
    public var caps: Bool
    public var lineHeight: Double?
    public var review: Bool
    /// Locale to use for Foundation/ICU calls when the language itself has little data (`bo` → `en`).
    public var intlFallback: String?
}

/// All copy for one language from `i18n.strings`.
public struct LanguageStrings: Codable, Equatable, Sendable {
    public var title: String
    /// Year, Month, Day, Hours, Minutes, Seconds, Hundredths.
    public var labels: [String]
    public var sep: String
    public var date: String
    public var cal: [String: String]
    public var auto: String
    public var era: [String: String]
    public var monthOf: String
    public var h24: String
    public var range: String
    public var hund: String
    public var vpn: String
    public var geo: String
    public var tz: String
    public var unknown: String
    public var fmt: [String: String]
    public var calendar: String
    public var location: String
    public var invert: String
    public var language: String
    public var controls: String
    public var ly: String
    public var kinds: [String]?
    public var weekdays: [String]?
    public var dayPeriods: [String]?
    public var dateLine: String?
}

public enum I18nError: Error, Equatable {
    case missingLanguage(String)
    case missingDigitSet(String)
}

/// Decoded `data/i18n.json` — the single source of user-visible strings.
public struct I18nCatalog: Codable, Equatable, Sendable {
    public var languages: [String]
    public var fallback: String
    public var meta: [String: LanguageMeta]
    public var digitSets: [String: String]
    public var strings: [String: LanguageStrings]

    public static func load(from data: Data) throws -> I18nCatalog {
        let catalog = try JSONDecoder().decode(I18nCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    /// Every language listed must have meta, strings, 7 labels and a known digit set.
    public func validate() throws {
        for code in languages {
            guard let m = meta[code], let s = strings[code], s.labels.count == Metric.allCases.count else {
                throw I18nError.missingLanguage(code)
            }
            guard let set = digitSets[m.digits.rawValue], set.count == 10 else {
                throw I18nError.missingDigitSet(m.digits.rawValue)
            }
        }
        guard strings[fallback] != nil else { throw I18nError.missingLanguage(fallback) }
    }

    public var fallbackLanguage: Language { Language(rawValue: fallback) ?? .en }

    public func meta(_ lang: Language) -> LanguageMeta {
        meta[lang.rawValue] ?? meta[fallback]!
    }

    public func strings(_ lang: Language) -> LanguageStrings {
        strings[lang.rawValue] ?? strings[fallback]!
    }

    /// Celestial kinds, falling back to the fallback language (`bo` has none).
    public func kinds(_ lang: Language) -> [String] {
        strings(lang).kinds ?? strings(fallbackLanguage).kinds ?? []
    }

    /// Locale identifier for Foundation formatting calls (`intlFallback` honoured).
    public func intlLocaleIdentifier(_ lang: Language) -> String {
        meta(lang).intlFallback ?? lang.rawValue
    }

    /// Applies the language's digit set to ASCII digits in `text`.
    public func digits(_ text: String, _ lang: Language) -> String {
        let set = meta(lang).digits
        guard set != .latn, let glyphs = digitSets[set.rawValue] else { return text }
        return Digits.map(text, to: glyphs)
    }

    public func label(_ metric: Metric, _ lang: Language) -> String {
        strings(lang).labels[metric.rawValue]
    }

    public func calendarName(_ id: CalendarID, _ lang: Language) -> String {
        strings(lang).cal[id.rawValue] ?? strings(fallbackLanguage).cal[id.rawValue] ?? id.rawValue
    }

    /// Short calendar name for the control pill: text before the first « · ».
    public func calendarShortName(_ id: CalendarID, _ lang: Language) -> String {
        let full = calendarName(id, lang)
        if let range = full.range(of: " · ") { return String(full[..<range.lowerBound]) }
        return full
    }

    public func era(_ id: CalendarID, _ lang: Language) -> String {
        strings(lang).era[id.rawValue] ?? strings(fallbackLanguage).era[id.rawValue] ?? ""
    }

    public func hourFormatName(_ format: HourFormat, _ lang: Language) -> String {
        strings(lang).fmt[String(format.rawValue)] ?? ""
    }
}
