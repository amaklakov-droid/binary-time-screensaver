import Foundation

/// The decoded data files. The host (saver, DebugHost or tests) reads the bytes from its own bundle
/// and hands them over; Core never touches `Bundle.module`, which breaks inside the screen-saver host.
public struct CoreResources: Sendable {
    public var tokens: Tokens
    public var i18n: I18nCatalog
    public var catalog: CelestialCatalog
    public var zones: ZoneTable

    public init(tokens: Tokens, i18n: I18nCatalog, catalog: CelestialCatalog, zones: ZoneTable) {
        self.tokens = tokens
        self.i18n = i18n
        self.catalog = catalog
        self.zones = zones
    }

    public init(tokensData: Data, i18nData: Data, catalogData: Data, zoneTableText: String) throws {
        let i18n = try I18nCatalog.load(from: i18nData)
        let catalog = try CelestialCatalog.load(from: catalogData)
        try catalog.validate(against: i18n)
        self.init(tokens: try Tokens.load(from: tokensData), i18n: i18n, catalog: catalog, zones: ZoneTable(parsing: zoneTableText))
    }
}
