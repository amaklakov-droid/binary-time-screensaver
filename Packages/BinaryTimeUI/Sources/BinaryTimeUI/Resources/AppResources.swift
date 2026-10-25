import Foundation
import BinaryTimeCore

public enum ResourceError: Error, CustomStringConvertible {
    case missing(String)
    public var description: String {
        switch self { case .missing(let name): return "Missing bundled resource: \(name)" }
    }
}

/// The decoded data files plus the font registry, loaded from a bundle (saver, DebugHost) or a checkout.
public struct AppResources {
    public let core: CoreResources
    public let fonts: FontRegistry

    public init(core: CoreResources, fonts: FontRegistry) {
        self.core = core
        self.fonts = fonts
    }

    /// Reads `tokens.json`, `i18n.json`, `celestial-catalog.json`, `zone.tab` and the `Fonts` folder from `bundle`.
    public init(bundle: Bundle) throws {
        func url(_ name: String, _ ext: String?) throws -> URL {
            guard let u = bundle.url(forResource: name, withExtension: ext) else {
                throw ResourceError.missing(ext.map { "\(name).\($0)" } ?? name)
            }
            return u
        }
        try self.init(tokens: url("tokens", "json"),
                      i18n: url("i18n", "json"),
                      catalog: url("celestial-catalog", "json"),
                      zoneTable: url("zone", "tab"),
                      fontsDirectory: bundle.url(forResource: "Fonts", withExtension: nil))
    }

    /// For tools and tests: reads straight from a repository checkout (`design/`, `data/`, `Fonts/`).
    public init(repositoryRoot root: URL) throws {
        try self.init(tokens: root.appendingPathComponent("design/tokens.json"),
                      i18n: root.appendingPathComponent("data/i18n.json"),
                      catalog: root.appendingPathComponent("data/celestial-catalog.json"),
                      zoneTable: root.appendingPathComponent("data/zone.tab"),
                      fontsDirectory: root.appendingPathComponent("Fonts", isDirectory: true))
    }

    public init(tokens: URL, i18n: URL, catalog: URL, zoneTable: URL, fontsDirectory: URL?) throws {
        let core = try CoreResources(
            tokensData: try Data(contentsOf: tokens),
            i18nData: try Data(contentsOf: i18n),
            catalogData: try Data(contentsOf: catalog),
            zoneTableText: String(decoding: try Data(contentsOf: zoneTable), as: UTF8.self)
        )
        self.core = core
        self.fonts = FontRegistry(fontsDirectory: fontsDirectory, tokens: core.tokens)
    }
}
