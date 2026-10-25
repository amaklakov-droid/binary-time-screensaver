import Foundation
import BinaryTimeCore

/// Command-line options, mirroring the prototype's URL parameters plus rendering controls:
/// `--lang ar --theme light --hour 12 --calendar islamic --location vpn --shape square --controls 0`
/// `--size 1440x900 --freeze 2026-10-24T19:59:17.800+03:00 --tz Europe/Moscow --space-index 12`
/// `--screenshot out.png --scale 1 --reset`
struct HostOptions {
    var language: LanguageSetting?
    var theme: Theme?
    var hourFormat: HourFormat?
    var calendar: CalendarSetting?
    var location: LocationMode?
    var bitShape: BitShape?
    var showControls: Bool?
    var size = CGSize(width: 1440, height: 900)
    var freeze: Date?
    var timeZone: TimeZone?
    var spaceIndex: Int?
    var screenshot: URL?
    var scale: CGFloat = 1
    var reset = false
    var errors: [String] = []

    var isHeadless: Bool { screenshot != nil }

    static func parse(_ arguments: [String]) -> HostOptions {
        var options = HostOptions()
        var iterator = arguments.dropFirst().makeIterator()
        func value(_ flag: String) -> String? {
            guard let v = iterator.next() else { options.errors.append("\(flag) needs a value"); return nil }
            return v
        }
        while let arg = iterator.next() {
            switch arg {
            case "--lang":
                if let v = value(arg) { options.language = LanguageSetting(rawValue: v) }
            case "--theme":
                if let v = value(arg) { options.theme = Theme(rawValue: v) ?? { options.errors.append("bad theme \(v)"); return nil }() }
            case "--hour", "--hourFormat":
                if let v = value(arg) { options.hourFormat = Int(v).flatMap(HourFormat.init(rawValue:)) ?? { options.errors.append("bad hour format \(v)"); return nil }() }
            case "--calendar":
                if let v = value(arg) { options.calendar = CalendarSetting(rawValue: v) ?? { options.errors.append("bad calendar \(v)"); return nil }() }
            case "--location":
                if let v = value(arg) { options.location = LocationMode(rawValue: v) ?? { options.errors.append("bad location \(v)"); return nil }() }
            case "--shape", "--bitShape":
                if let v = value(arg) { options.bitShape = BitShape(rawValue: v) ?? { options.errors.append("bad shape \(v)"); return nil }() }
            case "--controls", "--showControls":
                if let v = value(arg) { options.showControls = !(v == "0" || v.lowercased() == "false" || v.lowercased() == "no") }
            case "--size":
                if let v = value(arg) {
                    let parts = v.lowercased().split(separator: "x").compactMap { Double($0) }
                    if parts.count == 2, parts[0] > 0, parts[1] > 0 { options.size = CGSize(width: parts[0], height: parts[1]) } else { options.errors.append("bad size \(v)") }
                }
            case "--freeze":
                if let v = value(arg) {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    var date = f.date(from: v)
                    if date == nil { f.formatOptions = [.withInternetDateTime]; date = f.date(from: v) }
                    if let date { options.freeze = date } else { options.errors.append("bad --freeze date \(v)") }
                }
            case "--tz":
                if let v = value(arg) { options.timeZone = TimeZone(identifier: v) ?? { options.errors.append("unknown time zone \(v)"); return nil }() }
            case "--space-index", "--spaceIndex":
                if let v = value(arg) { options.spaceIndex = Int(v) ?? { options.errors.append("bad space index \(v)"); return nil }() }
            case "--screenshot":
                if let v = value(arg) { options.screenshot = URL(fileURLWithPath: v) }
            case "--scale":
                if let v = value(arg) { options.scale = CGFloat(Double(v) ?? 1) }
            case "--reset":
                options.reset = true
            default:
                if arg.hasPrefix("-NS") || arg.hasPrefix("-Apple") { _ = iterator.next(); continue } // AppKit's own flags
                options.errors.append("unknown argument \(arg)")
            }
        }
        return options
    }

    /// Applies the overrides on top of `base`.
    func apply(to base: Settings) -> Settings {
        var s = base
        if let language { s.language = language }
        if let theme { s.theme = theme }
        if let hourFormat { s.hourFormat = hourFormat }
        if let calendar { s.calendar = calendar }
        if let location { s.location = location }
        if let bitShape { s.bitShape = bitShape }
        if let showControls { s.showControls = showControls }
        return s
    }
}
