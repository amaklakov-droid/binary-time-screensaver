import Foundation

/// The four supported calendars (SPEC §4.2, MACOS.md §3).
public enum CalendarID: String, CaseIterable, Codable, Sendable {
    case gregory, islamic, hebrew, buddhist

    public var foundationIdentifier: Calendar.Identifier {
        switch self {
        case .gregory: return .gregorian
        case .islamic: return .islamicUmmAlQura
        case .hebrew: return .hebrew
        case .buddhist: return .buddhist
        }
    }

    /// Reverse mapping used for the OS calendar setting; only exact matches count.
    public init?(foundationIdentifier: Calendar.Identifier) {
        switch foundationIdentifier {
        case .gregorian: self = .gregory
        case .islamicUmmAlQura: self = .islamic
        case .hebrew: self = .hebrew
        case .buddhist: self = .buddhist
        default: return nil
        }
    }
}

/// The `calendar` setting (SPEC §6).
public enum CalendarSetting: String, CaseIterable, Codable, Sendable {
    case auto, gregory, islamic, hebrew, buddhist

    public var fixed: CalendarID? { CalendarID(rawValue: rawValue) }
}

/// Numeric date in the chosen calendar.
public struct DateParts: Equatable, Sendable {
    public var year: Int
    /// Ordinal month within the year, 1-based (Hebrew: Tishri = 1 … Elul = 12 or 13).
    public var month: Int
    public var day: Int
    /// 12, or 13 in a Hebrew leap year.
    public var monthsInYear: Int
    /// 0 = Sunday … 6 = Saturday.
    public var weekday: Int
    public var isLeapYear: Bool

    public init(year: Int, month: Int, day: Int, monthsInYear: Int, weekday: Int, isLeapYear: Bool) {
        self.year = year
        self.month = month
        self.day = day
        self.monthsInYear = monthsInYear
        self.weekday = weekday
        self.isLeapYear = isLeapYear
    }
}

public enum CalendarService {
    /// Time zones that imply a calendar when the OS setting does not (SPEC §4.2).
    static let zoneCalendars: [String: CalendarID] = [
        "Asia/Riyadh": .islamic,
        "Asia/Jerusalem": .hebrew,
        "Asia/Tel_Aviv": .hebrew,
        "Asia/Bangkok": .buddhist,
    ]

    /// `auto` rule: the user's own OS calendar if it is one of the four, else by time zone, else Gregorian.
    public static func resolveAuto(osCalendar: Calendar.Identifier?, timeZone: TimeZone) -> CalendarID {
        if let os = osCalendar, let id = CalendarID(foundationIdentifier: os) { return id }
        return zoneCalendars[timeZone.identifier] ?? .gregory
    }

    public static func resolve(_ setting: CalendarSetting, osCalendar: Calendar.Identifier?, timeZone: TimeZone) -> CalendarID {
        setting.fixed ?? resolveAuto(osCalendar: osCalendar, timeZone: timeZone)
    }

    public static func calendar(_ id: CalendarID, timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: id.foundationIdentifier)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// Y/M/D in `id`, with the Hebrew month converted to its ordinal within the year.
    public static func dateParts(_ date: Date, calendar id: CalendarID, timeZone: TimeZone) -> DateParts {
        let cal = calendar(id, timeZone: timeZone)
        let c = cal.dateComponents([.year, .month, .day, .weekday], from: date)
        let year = c.year ?? 1
        var month = c.month ?? 1
        var monthsInYear = 12
        var isLeap = false
        if id == .hebrew {
            isLeap = hebrewIsLeapYear(year, containing: date, calendar: cal)
            monthsInYear = isLeap ? 13 : 12
            month = hebrewOrdinalMonth(foundationMonth: month, isLeapYear: isLeap)
        }
        return DateParts(
            year: year,
            month: month,
            day: c.day ?? 1,
            monthsInYear: monthsInYear,
            weekday: max(0, (c.weekday ?? 1) - 1),
            isLeapYear: isLeap
        )
    }

    /// Foundation numbers Hebrew months 1–13 with 6 = Adar I (leap years only) and 7 = Adar / Adar II,
    /// so in a non-leap year months ≥ 7 are shifted down by one (Elul = 12). MACOS.md §3.
    public static func hebrewOrdinalMonth(foundationMonth: Int, isLeapYear: Bool) -> Int {
        if isLeapYear { return foundationMonth }
        return foundationMonth >= 7 ? foundationMonth - 1 : foundationMonth
    }

    /// Leap status by days in the year (383–385 vs 353–355). `range(of: .month, in: .year)` cannot be
    /// used: Foundation reports 13 months for every Hebrew year. Falls back to the 19-year cycle rule.
    static func hebrewIsLeapYear(_ year: Int, containing date: Date, calendar: Calendar) -> Bool {
        if let days = calendar.range(of: .day, in: .year, for: date)?.count {
            return days > 370
        }
        return hebrewIsLeapYear(arithmetic: year)
    }

    /// Metonic cycle rule: leap when `(7y + 1) mod 19 < 7`.
    public static func hebrewIsLeapYear(arithmetic year: Int) -> Bool {
        (7 * year + 1) % 19 < 7
    }
}
