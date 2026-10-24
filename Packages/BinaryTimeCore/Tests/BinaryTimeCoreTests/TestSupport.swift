import Foundation
import XCTest
@testable import BinaryTimeCore

/// Shared fixtures. Data files are read from the repository (`design/`, `data/`), never copied.
enum Fixtures {
    static let repoRoot: URL = {
        // CI or an external runner may point at the checkout explicitly.
        if let env = ProcessInfo.processInfo.environment["BINARY_TIME_REPO"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // …/Packages/BinaryTimeCore/Tests/BinaryTimeCoreTests/TestSupport.swift → repo root is five levels up.
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }()

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
    }

    static let resources: CoreResources = {
        do {
            return try CoreResources(
                tokensData: try data("design/tokens.json"),
                i18nData: try data("data/i18n.json"),
                catalogData: try data("data/celestial-catalog.json"),
                zoneTableText: String(decoding: try data("data/zone.tab"), as: UTF8.self)
            )
        } catch {
            fatalError("Cannot load fixtures from \(repoRoot.path): \(error)")
        }
    }()

    static var i18n: I18nCatalog { resources.i18n }
    static var tokens: Tokens { resources.tokens }
    static var catalog: CelestialCatalog { resources.catalog }
    static var zones: ZoneTable { resources.zones }

    static let moscow = TimeZone(identifier: "Europe/Moscow")!

    /// The instant shown on every reference screenshot: 2026-10-24 19:59:17.80 in Moscow.
    static let referenceInstant = date("2026-10-24T19:59:17.800+03:00")

    static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        guard let d = f.date(from: iso) else { fatalError("Bad ISO date \(iso)") }
        return d
    }

    static func object(_ id: String) -> CelestialObject {
        guard let o = catalog.objects.first(where: { $0.id == id }) else { fatalError("No catalog object \(id)") }
        return o
    }

    static func sample(_ iso: String, calendar: CalendarID = .gregory, zone: TimeZone = moscow) -> ClockSample {
        ClockSample.make(at: date(iso), timeZone: zone, calendar: calendar)
    }
}

/// Folds no-break spaces (U+00A0, U+202F) that Foundation inserts into localized dates to plain spaces.
func plainSpaces(_ text: String) -> String {
    text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
}

/// Deterministic generator for `SpaceRotator` tests.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
