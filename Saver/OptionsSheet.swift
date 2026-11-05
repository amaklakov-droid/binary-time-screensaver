import AppKit
import BinaryTimeCore
import BinaryTimeUI

/// The Options sheet (`configureSheet`), built in code: XIBs with the Xcode 26+ SDK crash on older
/// macOS (MACOS.md §2.7). Content comes from `OptionsSheetModel`; this class only lays it out.
/// Changing the language relabels the sheet at once; nothing is saved until OK.
final class OptionsSheet: NSObject {
    let window: NSWindow
    private let catalog: I18nCatalog
    private let fonts: FontRegistry
    private let completion: (Settings?) -> Void
    private var pending: Settings
    private var model: OptionsSheetModel

    private static let fontSize: CGFloat = 13
    private static let margin: CGFloat = 20

    /// `completion` gets the new settings on OK, `nil` on Cancel.
    init(catalog: I18nCatalog, fonts: FontRegistry, settings: Settings, completion: @escaping (Settings?) -> Void) {
        self.catalog = catalog
        self.fonts = fonts
        self.completion = completion
        pending = settings
        model = OptionsSheetModel(settings: settings, catalog: catalog, preferredLanguages: Locale.preferredLanguages)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300), styleMask: [.titled], backing: .buffered, defer: true)
        super.init()
        window.isReleasedWhenClosed = false
        rebuild()
    }

    /// The language's own bundled face (`i18n.meta.font`, so Tibetan stacks get its line height),
    /// cascading to the token font stack for the other scripts in the language menu.
    private var font: NSFont {
        let stack = fonts.font(weight: 400, size: Self.fontSize)
        let family = catalog.meta(model.language).font
        guard FontRegistry.isFamilyAvailable(family) else { return stack }
        let descriptor = NSFontDescriptor(fontAttributes: [.family: family, .cascadeList: [stack.fontDescriptor]])
        return NSFont(descriptor: descriptor, size: Self.fontSize) ?? stack
    }

    private func rebuild() {
        window.title = model.title
        let direction: NSUserInterfaceLayoutDirection = model.direction == .rtl ? .rightToLeft : .leftToRight

        let grid = NSGridView(views: model.rows.enumerated().map { index, row in [label(row.title), popUp(for: row, tag: index)] })
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        grid.rowAlignment = .firstBaseline

        let cancel = button(model.cancel, action: #selector(cancelPressed), key: "\u{1b}")
        let done = button(model.done, action: #selector(donePressed), key: "\r")
        let buttons = NSStackView(views: [cancel, done])
        buttons.spacing = 12

        let stack = NSStackView(views: [grid, buttons])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = Self.margin
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Margins as constraints: a stack view's own edge insets are dropped when it is the content view.
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.margin),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.margin),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.margin),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.margin),
        ])
        // AppKit mirrors grid columns and the button order for right-to-left languages.
        for view in [content, stack, grid, buttons] as [NSView] { view.userInterfaceLayoutDirection = direction }

        window.contentView = content
        window.setContentSize(content.fittingSize)
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.alignment = .natural
        return field
    }

    private func popUp(for row: OptionsSheetModel.Row, tag: Int) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.font = font
        button.menu?.font = font
        button.addItems(withTitles: row.choices.map(\.label))
        button.selectItem(at: row.selectedIndex)
        button.tag = tag
        button.target = self
        button.action = #selector(choiceChanged(_:))
        return button
    }

    private func button(_ title: String, action: Selector, key: String) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.font = font
        button.keyEquivalent = key
        return button
    }

    @objc private func choiceChanged(_ sender: NSPopUpButton) {
        let row = model.rows[sender.tag]
        let index = sender.indexOfSelectedItem
        guard row.choices.indices.contains(index) else { return }
        pending = OptionsSheetModel.applying(row.choices[index].value, to: row.field, in: pending)
        model = OptionsSheetModel(settings: pending, catalog: catalog, preferredLanguages: Locale.preferredLanguages)
        if row.field == .language { rebuild() }
    }

    @objc private func donePressed() { close(with: pending) }

    @objc private func cancelPressed() { close(with: nil) }

    /// Saves before ending the sheet: WallpaperAgent snapshots a fresh instance for the System Settings
    /// thumbnail as soon as the sheet ends, and that instance must read the new settings (MACOS.md §2.8).
    private func close(with result: Settings?) {
        completion(result)
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }
}
