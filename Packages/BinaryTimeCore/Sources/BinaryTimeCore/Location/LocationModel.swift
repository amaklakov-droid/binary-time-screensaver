import Foundation

/// City-level coordinates from the optional IP lookup (SPEC §4.3). Never persisted.
public struct Coordinates: Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// What the header's right block shows (SPEC §4.3–4.4). `l3` is empty when absent.
public struct LocationModel: Equatable, Sendable {
    public var tag: String
    public var l1: String
    public var l2: String
    public var l3: String

    public init(tag: String, l1: String, l2: String, l3: String = "") {
        self.tag = tag
        self.l1 = l1
        self.l2 = l2
        self.l3 = l3
    }
}

public enum LocationSource: Equatable, Sendable {
    /// Real location derived from the time zone, optionally refined by IP coordinates.
    case timeZone(TimeZone, coordinates: Coordinates? = nil)
    /// VPN or forced space mode: a catalog object instead of the real place.
    case space(CelestialObject)
}

/// Builds `LocationModel`s from the i18n catalog and the zone table.
public struct LocationResolver: Sendable {
    public let i18n: I18nCatalog
    public let zones: ZoneTable

    public init(i18n: I18nCatalog, zones: ZoneTable) {
        self.i18n = i18n
        self.zones = zones
    }

    public func model(for source: LocationSource, lang: Language) -> LocationModel {
        switch source {
        case .timeZone(let zone, let coordinates):
            return realPlace(zone: zone, coordinates: coordinates, lang: lang)
        case .space(let object):
            return space(object, lang: lang)
        }
    }

    // MARK: Real place

    func realPlace(zone: TimeZone, coordinates: Coordinates?, lang: Language) -> LocationModel {
        let t = i18n.strings(lang)
        let zoneID = zone.identifier
        let city = ZoneTable.cityName(forZone: zoneID)
        let country = zones.countryCode(forZone: zoneID).flatMap { localizedRegionName($0, lang: lang) }
        let coords = coordinates.map(LocationResolver.formatCoordinates)
        let tag = coordinates == nil ? t.tz : t.geo
        if let city {
            let l1 = country.map { "\(city) · \($0)" } ?? city
            return LocationModel(tag: tag, l1: l1, l2: coords ?? zoneID, l3: coords == nil ? "" : zoneID)
        }
        if let coords {
            return LocationModel(tag: tag, l1: coords, l2: zoneID)
        }
        return LocationModel(tag: tag, l1: t.unknown, l2: zoneID)
    }

    /// Region name in the language's Foundation locale (`intlFallback` honoured, so `bo` gets English).
    public func localizedRegionName(_ code: String, lang: Language) -> String? {
        let locale = Locale(identifier: i18n.intlLocaleIdentifier(lang))
        guard let name = locale.localizedString(forRegionCode: code), !name.isEmpty else { return nil }
        return name
    }

    /// `55.76° N · 37.62° E` — two decimals (city level), Latin digits.
    public static func formatCoordinates(_ c: Coordinates) -> String {
        let lat = String(format: "%.2f° %@", abs(c.latitude), c.latitude >= 0 ? "N" : "S")
        let lon = String(format: "%.2f° %@", abs(c.longitude), c.longitude >= 0 ? "E" : "W")
        return lat + " · " + lon
    }

    // MARK: Space

    func space(_ object: CelestialObject, lang: Language) -> LocationModel {
        let t = i18n.strings(lang)
        let kinds = i18n.kinds(lang)
        var l3 = object.kind >= 0 && object.kind < kinds.count ? kinds[object.kind] : ""
        if !object.designation.isEmpty { l3 += " · " + object.designation }
        if let distance = object.distanceLy {
            l3 += " · " + (object.approx ? "≈" : "") + formatDistance(distance, lang: lang) + " " + t.ly
        }
        let l2: String
        if let eq = object.coords {
            l2 = "RA \(eq.ra) · Dec \(eq.dec)"
        } else if let s = object.surface {
            l2 = "\(s.lat) · \(s.lon)"
        } else {
            l2 = ""
        }
        return LocationModel(tag: t.vpn, l1: object.name(lang, fallback: i18n.fallbackLanguage), l2: l2, l3: l3)
    }

    /// Light-years with the locale's grouping, at most two decimals, then the language's digits.
    public func formatDistance(_ value: Double, lang: Language) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: i18n.intlLocaleIdentifier(lang) + "@numbers=latn")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return i18n.digits(text, lang)
    }
}
