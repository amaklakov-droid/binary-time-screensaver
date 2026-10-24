import Foundation

/// Localized date line, short weekday and day period (SPEC §5, MACOS.md §3 «Calendars»).
///
/// Uses `DateFormatter` with `<lang>@numbers=latn` and maps digits afterwards. Tibetan has no
/// usable Foundation data, so its strings come from `i18n.strings.bo`. Not thread-safe: use on one queue.
public final class DateTextFormatter {
    private let catalog: I18nCatalog
    private var cache: [String: DateFormatter] = [:]

    public init(catalog: I18nCatalog) {
        self.catalog = catalog
    }

    /// Full date line for the header, e.g. «Saturday, October 24, 2026», «יום שבת, 13 בחשון 5787».
    public func dateLine(_ date: Date, parts: DateParts, calendar: CalendarID, lang: Language, timeZone: TimeZone) -> String {
        let t = catalog.strings(lang)
        if let template = t.dateLine, let weekdays = t.weekdays, weekdays.count == 7 {
            let text = template
                .replacingOccurrences(of: "{y}", with: String(parts.year))
                .replacingOccurrences(of: "{m}", with: String(parts.month))
                .replacingOccurrences(of: "{d}", with: String(parts.day))
                .replacingOccurrences(of: "{wd}", with: weekdays[parts.weekday])
            return catalog.digits(text, lang)
        }
        let formatter = self.formatter(key: "dateLine|\(lang.rawValue)|\(calendar.rawValue)|\(timeZone.identifier)", lang: lang, calendar: calendar, timeZone: timeZone) {
            $0.setLocalizedDateFormatFromTemplate("EEEEdMMMMy")
        }
        return catalog.digits(formatter.string(from: date), lang)
    }

    /// Short weekday for the day row sub-label («Sat», «сб», «土»).
    public func weekdayShort(_ date: Date, parts: DateParts, lang: Language, timeZone: TimeZone) -> String {
        let t = catalog.strings(lang)
        if let weekdays = t.weekdays, weekdays.count == 7 { return weekdays[parts.weekday] }
        // Apple's ICU data abbreviates as «Сб» / «سبت» in every formatting context; the browser prototype
        // (CLDR) shows «сб» / «السبت». Platform data is used as is — see the milestone 1 report.
        let formatter = self.formatter(key: "weekday|\(lang.rawValue)|\(timeZone.identifier)", lang: lang, calendar: .gregory, timeZone: timeZone) {
            $0.dateFormat = "EEE"
        }
        return formatter.string(from: date)
    }

    /// Localized AM/PM («PM», «م», «午後», «ཕྱི་དྲོ།»).
    public func dayPeriod(isPM: Bool, lang: Language) -> String {
        let t = catalog.strings(lang)
        if let periods = t.dayPeriods, periods.count == 2 { return periods[isPM ? 1 : 0] }
        let formatter = self.formatter(key: "period|\(lang.rawValue)", lang: lang, calendar: .gregory, timeZone: .current) { _ in }
        let symbol = isPM ? formatter.pmSymbol : formatter.amSymbol
        if let symbol, !symbol.isEmpty { return symbol }
        return isPM ? "PM" : "AM"
    }

    private func formatter(key: String, lang: Language, calendar: CalendarID, timeZone: TimeZone, configure: (DateFormatter) -> Void) -> DateFormatter {
        if let cached = cache[key] { return cached }
        let f = DateFormatter()
        f.locale = Locale(identifier: catalog.intlLocaleIdentifier(lang) + "@numbers=latn")
        var cal = Calendar(identifier: calendar.foundationIdentifier)
        cal.timeZone = timeZone
        f.calendar = cal
        f.timeZone = timeZone
        configure(f)
        cache[key] = f
        return f
    }
}
