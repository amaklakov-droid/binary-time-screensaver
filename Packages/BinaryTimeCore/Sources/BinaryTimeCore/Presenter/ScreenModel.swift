import Foundation

/// One row of the bit block, ready to render.
public struct RowModel: Equatable, Sendable {
    public var metric: Metric
    public var label: String
    public var sub: String
    public var decimal: String
    public var value: Int
    public var bits: Int
    public var states: [BitState]
    /// «<metric> <decimal> — <binary>» (SPEC §7).
    public var accessibilityLabel: String

    public var isDate: Bool { metric.isDate }
}

public struct HeaderModel: Equatable, Sendable {
    public var title: String
    /// «Gregorian · auto» or just the calendar name.
    public var calendarLine: String
    public var dateLine: String
}

public struct FooterModel: Equatable, Sendable {
    public var readout: String
    /// Localized AM/PM in 12 h mode, empty otherwise.
    public var dayPeriod: String
    public var utcOffset: String
}

/// Texts of the control pills (DebugHost only; SPEC §6).
public struct ControlsModel: Equatable, Sendable {
    public var language: String
    public var languageAccessibility: String
    public var hourFormat: String
    public var calendar: String
    public var location: String
    public var invert: String
    public var groupLabel: String
}

/// Everything a view needs for one frame. Views diff against the previous model and touch only what changed.
public struct ScreenModel: Equatable, Sendable {
    public var language: Language
    public var direction: TextDirection
    public var digits: DigitSet
    public var caps: Bool
    public var lineHeight: Double?
    public var theme: Theme
    public var bitShape: BitShape
    public var columns: Int
    public var placeValues: [String]
    public var header: HeaderModel
    public var location: LocationModel
    public var rows: [RowModel]
    public var separatorLabel: String
    public var dateGroupLabel: String
    public var timeGroupLabel: String
    public var footer: FooterModel
    public var controls: ControlsModel
    public var showControls: Bool

    /// Changes only when the layer tree must be rebuilt (column count or language).
    public var structureKey: String { "\(columns)|\(language.rawValue)" }

    public var dateRows: [RowModel] { rows.filter { $0.isDate } }
    public var timeRows: [RowModel] { rows.filter { !$0.isDate } }
}

/// Resolved inputs for one frame.
public struct FrameContext: Equatable, Sendable {
    public var instant: Date
    public var timeZone: TimeZone
    public var language: Language
    public var calendar: CalendarID
    public var settings: Settings
    public var location: LocationModel

    public init(instant: Date, timeZone: TimeZone, language: Language, calendar: CalendarID, settings: Settings, location: LocationModel) {
        self.instant = instant
        self.timeZone = timeZone
        self.language = language
        self.calendar = calendar
        self.settings = settings
        self.location = location
    }
}

/// Turns a `ClockSample` plus context into a `ScreenModel` (the prototype's `frame()` without the DOM).
public final class ScreenPresenter {
    public let i18n: I18nCatalog
    public let dateText: DateTextFormatter

    public init(i18n: I18nCatalog) {
        self.i18n = i18n
        self.dateText = DateTextFormatter(catalog: i18n)
    }

    public func model(sample: ClockSample, context: FrameContext) -> ScreenModel {
        let lang = context.language
        let meta = i18n.meta(lang)
        let t = i18n.strings(lang)
        let settings = context.settings
        let hourFormat = settings.hourFormat
        let columns = BinaryModel.columns(forYear: sample.date.year)
        let dig = { (s: String) in self.i18n.digits(s, lang) }

        let dayPeriod = hourFormat == .h12 ? dateText.dayPeriod(isPM: sample.isPM, lang: lang) : ""
        let weekday = dateText.weekdayShort(context.instant, parts: sample.date, lang: lang, timeZone: context.timeZone)

        let subs: [Metric: String] = [
            .year: i18n.era(context.calendar, lang),
            .month: t.monthOf.replacingOccurrences(of: "{n}", with: String(sample.date.monthsInYear)),
            .day: weekday,
            .hours: hourFormat == .h12 ? dayPeriod : t.h24.replacingOccurrences(of: "{n}", with: "24"),
            .minutes: t.range,
            .seconds: t.range,
        ]

        let rows = Metric.allCases.map { metric -> RowModel in
            let (value, bits) = sample.value(of: metric, hourFormat: hourFormat)
            let decimalRaw = metric == .year ? String(value) : Readout.pad2(value)
            let decimal = dig(decimalRaw)
            let label = i18n.label(metric, lang)
            return RowModel(
                metric: metric,
                label: label,
                sub: dig(subs[metric] ?? ""),
                decimal: decimal,
                value: value,
                bits: bits,
                states: BinaryModel.states(value: value, bits: bits, columns: columns),
                accessibilityLabel: "\(label) \(decimal) — \(BinaryModel.binaryString(value, bits: bits))"
            )
        }

        let calendarLine = i18n.calendarName(context.calendar, lang) + (settings.calendar == .auto ? " · " + t.auto : "")
        let header = HeaderModel(
            title: t.title,
            calendarLine: calendarLine,
            dateLine: dateText.dateLine(context.instant, parts: sample.date, calendar: context.calendar, lang: lang, timeZone: context.timeZone)
        )
        let footer = FooterModel(
            readout: Readout.text(sample: sample, hourFormat: hourFormat, lang: lang, catalog: i18n),
            dayPeriod: dayPeriod,
            utcOffset: Readout.utcOffset(timeZone: context.timeZone, at: context.instant)
        )
        let controls = ControlsModel(
            language: meta.native,
            languageAccessibility: "\(t.language): \(meta.native)",
            hourFormat: dig(i18n.hourFormatName(hourFormat, lang)),
            calendar: "\(t.calendar): " + (settings.calendar == .auto ? t.auto : i18n.calendarShortName(context.calendar, lang)),
            location: "\(t.location): " + (settings.location == .vpn ? "VPN" : t.auto),
            invert: t.invert,
            groupLabel: t.controls
        )

        return ScreenModel(
            language: lang,
            direction: meta.dir,
            digits: meta.digits,
            caps: meta.caps,
            lineHeight: meta.lineHeight,
            theme: settings.theme,
            bitShape: settings.bitShape,
            columns: columns,
            placeValues: BinaryModel.placeValues(columns: columns).map { dig(String($0)) },
            header: header,
            location: context.location,
            rows: rows,
            separatorLabel: t.sep,
            dateGroupLabel: t.date,
            timeGroupLabel: t.sep,
            footer: footer,
            controls: controls,
            showControls: settings.showControls
        )
    }
}
