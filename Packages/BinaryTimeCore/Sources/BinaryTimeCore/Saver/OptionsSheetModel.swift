import Foundation

/// Content of the screen saver's Options sheet (MACOS.md §3 «Settings»), localized from `i18n.json`.
/// The sheet view only lays out `rows`; choosing a value goes back through `applying(_:to:)`.
/// The online VPN check (SPEC §4.4) arrives with milestone 5 and has no row yet.
public struct OptionsSheetModel: Equatable, Sendable {
    public enum Field: String, CaseIterable, Sendable {
        case language, hourFormat, calendar, theme, bitShape, location
    }

    public struct Choice: Equatable, Sendable {
        /// Raw settings value, as persisted (SPEC §6).
        public var value: String
        public var label: String
    }

    public struct Row: Equatable, Sendable {
        public var field: Field
        public var title: String
        public var choices: [Choice]
        public var selectedIndex: Int
    }

    /// Language the sheet is written in: the chosen one, or the system's for `auto`.
    public var language: Language
    public var direction: TextDirection
    public var title: String
    public var rows: [Row]
    public var done: String
    public var cancel: String

    public init(settings: Settings, catalog: I18nCatalog, preferredLanguages: [String]) {
        let lang = settings.language.resolve(preferredLanguages: preferredLanguages)
        let s = catalog.strings(lang)
        let o = s.options
        let locale = Locale(identifier: catalog.intlLocaleIdentifier(lang))
        func label(_ text: String) -> String { catalog.digits(OptionsSheetModel.sentenceCase(text, locale: locale), lang) }
        func row(_ field: Field, _ title: String, _ choices: [(String, String)], selected: String) -> Row {
            let mapped = choices.map { Choice(value: $0.0, label: label($0.1)) }
            return Row(field: field, title: label(title), choices: mapped,
                       selectedIndex: mapped.firstIndex(where: { $0.value == selected }) ?? 0)
        }

        language = lang
        direction = catalog.meta(lang).dir
        title = label(s.controls)
        done = label(o.done)
        cancel = label(o.cancel)
        rows = [
            row(.language, s.language,
                [(LanguageSetting.auto.rawValue, s.auto)] + Language.allCases.map { ($0.rawValue, catalog.meta($0).native) },
                selected: settings.language.rawValue),
            row(.hourFormat, o.timeFormat,
                [HourFormat.h24, .h12].map { (String($0.rawValue), catalog.hourFormatName($0, lang)) },
                selected: String(settings.hourFormat.rawValue)),
            row(.calendar, s.calendar,
                CalendarSetting.allCases.map { ($0.rawValue, $0.fixed.map { catalog.calendarName($0, lang) } ?? s.auto) },
                selected: settings.calendar.rawValue),
            row(.theme, o.theme, [(Theme.dark.rawValue, o.dark), (Theme.light.rawValue, o.light)],
                selected: settings.theme.rawValue),
            row(.bitShape, o.bitShape, [(BitShape.dot.rawValue, o.dot), (BitShape.square.rawValue, o.square)],
                selected: settings.bitShape.rawValue),
            row(.location, s.location, [(LocationMode.auto.rawValue, s.auto), (LocationMode.vpn.rawValue, o.space)],
                selected: settings.location.rawValue),
        ]
    }

    /// Settings with `field` set to the raw `value`; unknown values leave them unchanged.
    public static func applying(_ value: String, to field: Field, in settings: Settings) -> Settings {
        var s = settings
        switch field {
        case .language: s.language = LanguageSetting(rawValue: value)
        case .hourFormat: if let n = Int(value), let f = HourFormat(rawValue: n) { s.hourFormat = f }
        case .calendar: if let c = CalendarSetting(rawValue: value) { s.calendar = c }
        case .theme: if let t = Theme(rawValue: value) { s.theme = t }
        case .bitShape: if let b = BitShape(rawValue: value) { s.bitShape = b }
        case .location: if let l = LocationMode(rawValue: value) { s.location = l }
        }
        return s
    }

    /// Menu items start with a capital where the script has case («auto» → «Auto»); other scripts are unchanged.
    static func sentenceCase(_ text: String, locale: Locale) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased(with: locale) + text.dropFirst()
    }
}
