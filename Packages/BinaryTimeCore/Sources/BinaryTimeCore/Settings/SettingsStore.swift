import Foundation

/// Key-value storage for settings. `UserDefaults` conforms, and so does the saver's
/// `ScreenSaverDefaults` (a subclass); tests use an in-memory one.
public protocol SettingsStorage: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension UserDefaults: SettingsStorage {}

/// Persists `Settings` key by key (SPEC §6 names).
public struct SettingsStore {
    public let storage: SettingsStorage

    public init(storage: SettingsStorage) {
        self.storage = storage
    }

    public func load() -> Settings {
        var stored: [String: Any] = [:]
        for key in Settings.Key.allCases {
            if let value = storage.object(forKey: key.rawValue) { stored[key.rawValue] = value }
        }
        return Settings(dictionary: stored)
    }

    public func save(_ settings: Settings) {
        for (key, value) in settings.dictionaryRepresentation {
            storage.set(value, forKey: key)
        }
        // ScreenSaverDefaults only writes through on synchronize; other hosts read the file.
        storage.synchronize()
    }
}
