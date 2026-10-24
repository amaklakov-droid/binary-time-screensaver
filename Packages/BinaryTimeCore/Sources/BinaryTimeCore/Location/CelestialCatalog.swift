import Foundation

public struct EquatorialCoordinates: Codable, Equatable, Sendable {
    public var ra: String
    public var dec: String
}

public struct SurfaceCoordinates: Codable, Equatable, Sendable {
    public var body: String
    public var lat: String
    public var lon: String
}

/// One entry of `data/celestial-catalog.json`.
public struct CelestialObject: Codable, Equatable, Sendable {
    public var id: String
    /// Index into `i18n.strings.<lang>.kinds`.
    public var kind: Int
    public var designation: String
    public var distanceLy: Double?
    public var approx: Bool
    public var coords: EquatorialCoordinates?
    public var surface: SurfaceCoordinates?
    public var names: [String: String]

    public func name(_ lang: Language, fallback: Language) -> String {
        names[lang.rawValue] ?? names[fallback.rawValue] ?? id
    }
}

public enum CatalogError: Error, Equatable {
    case empty
    case kindOutOfRange(id: String, kind: Int)
}

public struct CelestialCatalog: Codable, Equatable, Sendable {
    public var rotateEverySeconds: Double
    public var objects: [CelestialObject]

    public static func load(from data: Data) throws -> CelestialCatalog {
        let catalog = try JSONDecoder().decode(CelestialCatalog.self, from: data)
        guard !catalog.objects.isEmpty else { throw CatalogError.empty }
        return catalog
    }

    /// Every `kind` must have a string in the fallback language.
    public func validate(against i18n: I18nCatalog) throws {
        let kinds = i18n.kinds(i18n.fallbackLanguage)
        for object in objects where object.kind < 0 || object.kind >= kinds.count {
            throw CatalogError.kindOutOfRange(id: object.id, kind: object.kind)
        }
    }
}

/// Picks the object to show in VPN mode: random start, then the next one every `period` seconds.
/// A pure function of time, so every screen in the process agrees and tests are deterministic.
public struct SpaceRotator: Equatable, Sendable {
    public let count: Int
    public let period: TimeInterval
    public let epoch: Date
    public private(set) var startIndex: Int

    public init(count: Int, period: TimeInterval, epoch: Date, startIndex: Int) {
        self.count = max(1, count)
        self.period = max(1, period)
        self.epoch = epoch
        self.startIndex = ((startIndex % self.count) + self.count) % self.count
    }

    public init<G: RandomNumberGenerator>(catalog: CelestialCatalog, now: Date, using generator: inout G) {
        self.init(count: catalog.objects.count,
                  period: catalog.rotateEverySeconds,
                  epoch: now,
                  startIndex: Int.random(in: 0..<max(1, catalog.objects.count), using: &generator))
    }

    public init(catalog: CelestialCatalog, now: Date = Date()) {
        var g = SystemRandomNumberGenerator()
        self.init(catalog: catalog, now: now, using: &g)
    }

    public func index(at date: Date) -> Int {
        let elapsed = max(0, date.timeIntervalSince(epoch))
        let steps = Int(elapsed / period)
        return (startIndex + steps) % count
    }

    /// Skips to the next object (debug control «Location» toggles do this).
    public mutating func advance() {
        startIndex = (startIndex + 1) % count
    }
}
