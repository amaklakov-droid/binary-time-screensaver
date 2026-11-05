import Foundation

/// 12- or 24-hour display (SPEC §4.1).
public enum HourFormat: Int, Codable, CaseIterable, Sendable {
    case h24 = 24
    case h12 = 12

    /// Bits used by the hours row: 5 in 24 h mode, 4 in 12 h mode.
    public var hourBits: Int { self == .h24 ? 5 : 4 }
}

/// Everything the display needs about one instant, already split per calendar.
public struct ClockSample: Equatable, Sendable {
    public var date: DateParts
    public var hour24: Int
    public var minute: Int
    public var second: Int

    public init(date: DateParts, hour24: Int, minute: Int, second: Int) {
        self.date = date
        self.hour24 = hour24
        self.minute = minute
        self.second = second
    }

    public var isPM: Bool { hour24 >= 12 }

    /// Hours as shown: 0–23, or 1–12 in 12 h mode (`0 → 12`, `13 → 1`).
    public func displayHour(_ format: HourFormat) -> Int {
        switch format {
        case .h24: return hour24
        case .h12: return hour24 % 12 == 0 ? 12 : hour24 % 12
        }
    }

    /// Value and bit width of each metric for this sample (SPEC §2.2).
    public func value(of metric: Metric, hourFormat: HourFormat) -> (value: Int, bits: Int) {
        switch metric {
        case .year: return (date.year, BinaryModel.bitLength(date.year))
        case .month: return (date.month, 4)
        case .day: return (date.day, 5)
        case .hours: return (displayHour(hourFormat), hourFormat.hourBits)
        case .minutes: return (minute, 6)
        case .seconds: return (second, 6)
        }
    }

    /// Builds a sample for `instant` in `timeZone`, with the date expressed in `calendar`.
    ///
    /// Time of day is taken from the Gregorian calendar (identical in all four calendars), after snapping
    /// to whole milliseconds so an instant just before a second boundary never reads as the next second.
    public static func make(at instant: Date, timeZone: TimeZone, calendar: CalendarID) -> ClockSample {
        let milliseconds = Int64((instant.timeIntervalSince1970 * 1000).rounded())
        let snapped = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let time = gregorian.dateComponents([.hour, .minute, .second], from: snapped)
        return ClockSample(
            date: CalendarService.dateParts(snapped, calendar: calendar, timeZone: timeZone),
            hour24: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0
        )
    }
}
