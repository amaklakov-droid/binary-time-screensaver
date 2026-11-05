import Foundation

/// Produces one `ScreenModel` per displayed second. Repeated calls within the same second (re-renders after
/// a settings or size change) return the cached model.
public final class FrameComposer {
    public let resources: CoreResources
    public let presenter: ScreenPresenter
    public let locationResolver: LocationResolver

    /// Resolved per frame from `settings`, the OS and the time zone.
    public var settings: Settings { didSet { invalidate() } }
    public var timeZone: TimeZone { didSet { invalidate() } }
    public var preferredLanguages: [String] { didSet { invalidate() } }
    public var osCalendar: Calendar.Identifier? { didSet { invalidate() } }
    /// Layer-1/2 VPN verdict supplied by the host (nil = not checked yet → not a VPN).
    public var vpnDetected = false { didSet { invalidate() } }
    /// Coordinates from the optional IP lookup; never persisted.
    public var coordinates: Coordinates? { didSet { invalidate() } }
    public var spaceRotator: SpaceRotator { didSet { invalidate() } }

    private var cachedSecondKey: String?
    private var cachedModel: ScreenModel?
    private var cachedSpaceIndex = -1

    public init(resources: CoreResources,
                settings: Settings = .default,
                timeZone: TimeZone = .current,
                preferredLanguages: [String] = Locale.preferredLanguages,
                osCalendar: Calendar.Identifier? = Locale.current.calendar.identifier,
                spaceRotator: SpaceRotator? = nil,
                now: Date = Date()) {
        self.resources = resources
        self.presenter = ScreenPresenter(i18n: resources.i18n)
        self.locationResolver = LocationResolver(i18n: resources.i18n, zones: resources.zones)
        self.settings = settings
        self.timeZone = timeZone
        self.preferredLanguages = preferredLanguages
        self.osCalendar = osCalendar
        self.spaceRotator = spaceRotator ?? SpaceRotator(catalog: resources.catalog, now: now)
    }

    public var language: Language { settings.language.resolve(preferredLanguages: preferredLanguages) }
    public var calendar: CalendarID { CalendarService.resolve(settings.calendar, osCalendar: osCalendar, timeZone: timeZone) }
    public var isSpaceMode: Bool { settings.location == .vpn || vpnDetected }

    public func locationSource(at instant: Date) -> LocationSource {
        if isSpaceMode {
            let objects = resources.catalog.objects
            return .space(objects[spaceRotator.index(at: instant) % objects.count])
        }
        return .timeZone(timeZone, coordinates: coordinates)
    }

    public func invalidate() {
        cachedSecondKey = nil
        cachedModel = nil
    }

    /// The model for `instant`. Equal inputs within one second return the cached model.
    public func frame(at instant: Date) -> ScreenModel {
        let sample = ClockSample.make(at: instant, timeZone: timeZone, calendar: calendar)
        let spaceIndex = isSpaceMode ? spaceRotator.index(at: instant) : -1
        let secondKey = "\(sample.date.year)-\(sample.date.month)-\(sample.date.day) \(sample.hour24):\(sample.minute):\(sample.second)"
        if let cached = cachedModel, cachedSecondKey == secondKey, cachedSpaceIndex == spaceIndex {
            return cached
        }
        let location = locationResolver.model(for: locationSource(at: instant), lang: language)
        let context = FrameContext(instant: instant, timeZone: timeZone, language: language, calendar: calendar, settings: settings, location: location)
        let model = presenter.model(sample: sample, context: context)
        cachedModel = model
        cachedSecondKey = secondKey
        cachedSpaceIndex = spaceIndex
        return model
    }
}
