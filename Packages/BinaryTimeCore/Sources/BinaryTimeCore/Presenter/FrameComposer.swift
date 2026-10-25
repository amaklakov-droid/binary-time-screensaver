import Foundation

/// Produces one `ScreenModel` per frame. The full model (date line, labels, location) is rebuilt only
/// when the second changes; in between only the hundredths row and the readout are patched, so a
/// 60–120 Hz display link costs a few string operations per frame (SPEC §8).
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

    /// The model for `instant`. Equal inputs within one second return the cached full model with the
    /// hundredths row and readout patched.
    public func frame(at instant: Date) -> ScreenModel {
        let sample = ClockSample.make(at: instant, timeZone: timeZone, calendar: calendar)
        let spaceIndex = isSpaceMode ? spaceRotator.index(at: instant) : -1
        let secondKey = "\(sample.date.year)-\(sample.date.month)-\(sample.date.day) \(sample.hour24):\(sample.minute):\(sample.second)"
        if let cached = cachedModel, cachedSecondKey == secondKey, cachedSpaceIndex == spaceIndex {
            return presenter.patchingFastRows(cached, sample: sample, settings: settings)
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

public extension ScreenPresenter {
    /// Returns `model` with the hundredths row and the readout recomputed for `sample`.
    /// Everything else is unchanged within the same second.
    func patchingFastRows(_ model: ScreenModel, sample: ClockSample, settings: Settings) -> ScreenModel {
        var patched = model
        let (value, bits) = sample.value(of: .hundredths, hourFormat: settings.hourFormat)
        let decimal = i18n.digits(Readout.pad2(value), model.language)
        if let index = patched.rows.firstIndex(where: { $0.metric == .hundredths }) {
            var row = patched.rows[index]
            row.value = value
            row.decimal = decimal
            row.states = BinaryModel.states(value: value, bits: bits, columns: model.columns)
            row.accessibilityLabel = "\(row.label) \(decimal) — \(BinaryModel.binaryString(value, bits: bits))"
            patched.rows[index] = row
        }
        patched.footer.readout = Readout.text(sample: sample, hourFormat: settings.hourFormat, lang: model.language, catalog: i18n)
        return patched
    }
}
