import AppKit
import CoreText
import BinaryTimeCore

/// Registers the bundled OFL fonts for this process and builds fonts with the cascade list from
/// `tokens.font.stack` and tabular numerals (MACOS.md §3 «Fonts and text»).
public final class FontRegistry {
    public let primaryFamily: String
    public let cascadeFamilies: [String]
    public private(set) var registeredURLs: [URL] = []
    /// Families from the token stack that are not available after registration (bundle incomplete).
    public private(set) var missingFamilies: [String] = []
    private var cache: [String: NSFont] = [:]

    public var isComplete: Bool { missingFamilies.isEmpty }

    /// Generic CSS family names in the token stack that have no font file.
    static let genericFamilies: Set<String> = ["ui-monospace", "monospace", "sans-serif", "serif", "system-ui", "Menlo"]
    static let systemFallbackFamily = "Menlo"

    public init(fontsDirectory: URL?, tokens: Tokens) {
        let families = tokens.fontStack.filter { !FontRegistry.genericFamilies.contains($0) }
        primaryFamily = families.first ?? FontRegistry.systemFallbackFamily
        cascadeFamilies = Array(families.dropFirst())
        if let dir = fontsDirectory { register(directory: dir) }
        missingFamilies = families.filter { !FontRegistry.isFamilyAvailable($0) }
    }

    /// Registers every `.ttf`/`.otf`/`.ttc` under `directory` with process scope.
    public func register(directory: URL) {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator where ["ttf", "otf", "ttc"].contains(url.pathExtension.lowercased()) {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                registeredURLs.append(url)
            } else if let err = error?.takeRetainedValue(), CFErrorGetCode(err) == CTFontManagerError.alreadyRegistered.rawValue {
                registeredURLs.append(url)
            }
        }
    }

    public static func isFamilyAvailable(_ family: String) -> Bool {
        let descriptor = NSFontDescriptor(fontAttributes: [.family: family])
        return descriptor.matchingFontDescriptor(withMandatoryKeys: [.family]) != nil
    }

    /// CSS weight (300/400/600) → AppKit weight.
    public static func weight(css: Int) -> NSFont.Weight {
        switch css {
        case ..<250: return .thin
        case ..<350: return .light
        case ..<500: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        default: return .bold
        }
    }

    /// Primary family at `weight`, falling back through the Noto families, with monospaced digits.
    public func font(weight: Int, size: CGFloat) -> NSFont {
        let key = "\(weight)|\(size)"
        if let cached = cache[key] { return cached }
        let font = makeFont(weight: weight, size: size)
        cache[key] = font
        return font
    }

    private func descriptor(family: String, weight: Int) -> NSFontDescriptor {
        NSFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [NSFontDescriptor.TraitKey.weight: FontRegistry.weight(css: weight).rawValue],
        ])
    }

    private func makeFont(weight: Int, size: CGFloat) -> NSFont {
        let primary = FontRegistry.isFamilyAvailable(primaryFamily) ? primaryFamily : FontRegistry.systemFallbackFamily
        let cascade = cascadeFamilies.filter(FontRegistry.isFamilyAvailable).map { descriptor(family: $0, weight: weight) }
        let tabular: [[NSFontDescriptor.FeatureKey: Any]] = [[
            .typeIdentifier: kNumberSpacingType,
            .selectorIdentifier: kMonospacedNumbersSelector,
        ]]
        let attributes: [NSFontDescriptor.AttributeName: Any] = [
            .family: primary,
            .traits: [NSFontDescriptor.TraitKey.weight: FontRegistry.weight(css: weight).rawValue],
            .cascadeList: cascade,
            .featureSettings: tabular,
        ]
        let fontDescriptor = NSFontDescriptor(fontAttributes: attributes)
        return NSFont(descriptor: fontDescriptor, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: FontRegistry.weight(css: weight))
    }
}
