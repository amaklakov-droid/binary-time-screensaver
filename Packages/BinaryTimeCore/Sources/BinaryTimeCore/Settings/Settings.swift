import Foundation

public enum LocationMode: String, Codable, CaseIterable, Sendable { case auto, vpn }
public enum Theme: String, Codable, CaseIterable, Sendable { case dark, light }
public enum BitShape: String, Codable, CaseIterable, Sendable { case dot, square }

/// `lang` setting: `auto` or one of the six languages.
public enum LanguageSetting: Equatable, Sendable {
    case auto
    case fixed(Language)

    public init(rawValue: String) {
        if let lang = Language(rawValue: rawValue) { self = .fixed(lang) } else { self = .auto }
    }

    public var rawValue: String {
        switch self {
        case .auto: return "auto"
        case .fixed(let lang): return lang.rawValue
        }
    }

    public func resolve(preferredLanguages: [String]) -> Language {
        switch self {
        case .fixed(let lang): return lang
        case .auto: return Language.resolveDefault(preferred: preferredLanguages)
        }
    }
}

/// User settings (SPEC §6) plus the optional online VPN check (SPEC §4.4).
/// Storage-agnostic: the saver persists `dictionaryRepresentation` in `ScreenSaverDefaults`.
public struct Settings: Equatable, Sendable {
    public var language: LanguageSetting = .auto
    public var hourFormat: HourFormat = .h24
    public var calendar: CalendarSetting = .auto
    public var location: LocationMode = .auto
    public var theme: Theme = .dark
    public var bitShape: BitShape = .dot
    public var showControls = true
    public var onlineVPNCheck = false
    public var apiKey = ""

    public init() {}

    public static let `default` = Settings()

    /// Persisted keys, named as in SPEC §6.
    public enum Key: String, CaseIterable, Sendable {
        case lang, hourFormat, calendar, location, theme, bitShape, showControls, onlineVPNCheck, apiKey
    }

    /// Tolerant decoding: unknown or malformed values keep their defaults.
    public init(dictionary: [String: Any]) {
        self.init()
        if let v = dictionary[Key.lang.rawValue] as? String { language = LanguageSetting(rawValue: v) }
        if let v = dictionary[Key.hourFormat.rawValue], let n = Settings.int(v), let f = HourFormat(rawValue: n) { hourFormat = f }
        if let v = dictionary[Key.calendar.rawValue] as? String, let c = CalendarSetting(rawValue: v) { calendar = c }
        if let v = dictionary[Key.location.rawValue] as? String, let l = LocationMode(rawValue: v) { location = l }
        if let v = dictionary[Key.theme.rawValue] as? String, let t = Theme(rawValue: v) { theme = t }
        if let v = dictionary[Key.bitShape.rawValue] as? String, let s = BitShape(rawValue: v) { bitShape = s }
        if let v = dictionary[Key.showControls.rawValue] as? Bool { showControls = v }
        if let v = dictionary[Key.onlineVPNCheck.rawValue] as? Bool { onlineVPNCheck = v }
        if let v = dictionary[Key.apiKey.rawValue] as? String { apiKey = v }
    }

    public var dictionaryRepresentation: [String: Any] {
        [
            Key.lang.rawValue: language.rawValue,
            Key.hourFormat.rawValue: hourFormat.rawValue,
            Key.calendar.rawValue: calendar.rawValue,
            Key.location.rawValue: location.rawValue,
            Key.theme.rawValue: theme.rawValue,
            Key.bitShape.rawValue: bitShape.rawValue,
            Key.showControls.rawValue: showControls,
            Key.onlineVPNCheck.rawValue: onlineVPNCheck,
            Key.apiKey.rawValue: apiKey,
        ]
    }

    private static func int(_ value: Any) -> Int? {
        if let n = value as? Int { return n }
        if let s = value as? String { return Int(s) }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }
}
