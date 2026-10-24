import Foundation

/// The footer readout `YYYY·MM·DD  HH:MM:SS.cc` and the UTC offset legend (SPEC §2, §5).
public enum Readout {
    /// Left-to-right mark; keeps non-Latin digit groups in LTR order (Unicode bidi rule N1).
    public static let lrm = "\u{200E}"
    /// Typographic minus for negative offsets.
    public static let minus = "\u{2212}"

    public static func pad2(_ n: Int) -> String {
        n < 10 && n >= 0 ? "0\(n)" : String(n)
    }

    /// Full readout with the language's digits. Arabic uses `/` as the date separator because
    /// the Arabic zero `٠` looks like a middle dot; non-Latin digits get LRM around separators.
    public static func text(sample: ClockSample, hourFormat: HourFormat, lang: Language, catalog: I18nCatalog) -> String {
        let digits = catalog.meta(lang).digits
        let dateSep: String
        let groupSep: String
        switch digits {
        case .latn:
            dateSep = "·"
            groupSep = "  "
        case .arab:
            dateSep = lrm + "/" + lrm
            groupSep = lrm + "  " + lrm
        case .tibt:
            dateSep = lrm + "·" + lrm
            groupSep = lrm + "  " + lrm
        }
        let d = sample.date
        let raw = String(d.year) + dateSep + pad2(d.month) + dateSep + pad2(d.day) + groupSep
            + pad2(sample.displayHour(hourFormat)) + ":" + pad2(sample.minute) + ":" + pad2(sample.second) + "." + pad2(sample.hundredth)
        return catalog.digits(raw, lang)
    }

    /// `UTC+03:00`, `UTC−05:00`, `UTC+05:30` (Latin digits, always LTR).
    public static func utcOffset(timeZone: TimeZone, at date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : minus
        let total = abs(seconds) / 60
        return "UTC" + sign + pad2(total / 60) + ":" + pad2(total % 60)
    }
}
