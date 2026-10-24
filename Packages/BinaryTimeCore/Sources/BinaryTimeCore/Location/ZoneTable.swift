import Foundation

/// IANA `zone1970.tab` / `zone.tab`: time zone → country code(s). Both formats share
/// `codes<TAB>coordinates<TAB>zone[<TAB>comments]`; `zone1970.tab` separates several codes with commas,
/// the first being the zone's home country.
public struct ZoneTable: Equatable, Sendable {
    private var countryByZone: [String: String]

    public init(parsing text: String) {
        var table: [String: String] = [:]
        for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" }) {
            if line.hasPrefix("#") || line.isEmpty { continue }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 3 else { continue }
            let codes = fields[0].split(separator: ",")
            guard let home = codes.first, !home.isEmpty else { continue }
            table[String(fields[2])] = String(home)
        }
        countryByZone = table
    }

    public init(entries: [String: String]) {
        countryByZone = entries
    }

    public var count: Int { countryByZone.count }

    /// ISO 3166 code of the zone's home country, or nil when the zone is not in the table.
    public func countryCode(forZone identifier: String) -> String? {
        countryByZone[identifier] ?? countryByZone[ZoneTable.canonicalZoneID(identifier)]
    }

    /// Legacy aliases that macOS may still report. Kept minimal; `Asia/Tel_Aviv` is named in SPEC §4.2.
    static let aliases: [String: String] = [
        "Asia/Tel_Aviv": "Asia/Jerusalem",
        "Asia/Calcutta": "Asia/Kolkata",
        "Asia/Saigon": "Asia/Ho_Chi_Minh",
        "Asia/Katmandu": "Asia/Kathmandu",
        "Asia/Rangoon": "Asia/Yangon",
        "Europe/Kiev": "Europe/Kyiv",
        "America/Buenos_Aires": "America/Argentina/Buenos_Aires",
    ]

    public static func canonicalZoneID(_ identifier: String) -> String {
        aliases[identifier] ?? identifier
    }

    /// City from the last segment of the zone id (`Europe/Moscow` → «Moscow», `America/Argentina/Buenos_Aires`
    /// → «Buenos Aires»). Nil for zones without a region prefix (`UTC`, `GMT`) and for `Etc/*`.
    public static func cityName(forZone identifier: String) -> String? {
        let parts = identifier.split(separator: "/")
        guard parts.count > 1, parts[0] != "Etc", let last = parts.last, !last.isEmpty else { return nil }
        return last.replacingOccurrences(of: "_", with: " ")
    }
}
