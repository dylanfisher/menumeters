import AppKit

/// A meter's status item: the meter's view drawn in its button, its menu, and the items every
/// meter's menu ends with. Each meter controller owns one.
@MainActor
final class MeterStatusItem: NSObject {
    private let item: NSStatusItem
    private let showSettings: () -> Void

    /// `autosaveName` keeps the item's place in the menu bar across launches. The meter sets
    /// `menuDelegate` once it exists.
    init(
        autosaveName: String, accessibilityLabel: String, view: NSView,
        showSettings: @escaping () -> Void
    ) {
        item = NSStatusBar.system.statusItem(withLength: view.frame.width)
        self.showSettings = showSettings
        super.init()
        item.autosaveName = autosaveName
        button.setAccessibilityLabel(accessibilityLabel)
        place(view)
        item.menu = NSMenu()
    }

    /// Fills the menu as it opens; the menu holds it weakly.
    var menuDelegate: (any NSMenuDelegate)? {
        get { item.menu?.delegate }
        set { item.menu?.delegate = newValue }
    }

    /// Whether the item is in the menu bar; false while its meter is off.
    var isVisible: Bool {
        get { item.isVisible }
        set { item.isVisible = newValue }
    }

    /// Whether the meter is on but macOS isn't showing it: a crowded menu bar leaves the item
    /// without a screen, or behind the active app's menus. Also true while the whole menu bar
    /// is hidden, which `HiddenMeterNotice` checks for itself.
    var isHiddenByMenuBar: Bool {
        guard item.isVisible else { return false }
        guard let window = item.button?.window, window.screen != nil else { return true }
        return !window.occlusionState.contains(.visible)
    }

    /// The item's width in points.
    var widthPoints: CGFloat { item.length }

    /// Shows `new` in place of `old`, resizing the item to fit it.
    func replace(_ old: NSView, with new: NSView) {
        old.removeFromSuperview()
        item.length = new.frame.width
        place(new)
    }

    /// Adds the separator, Settings… and Quit items a meter's menu ends with.
    func addClosingItems(to menu: NSMenu) {
        menu.addItem(.separator())
        let settings = NSMenuItem(
            title: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(
            withTitle: "Quit MenuMeters", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
    }

    /// A line of the menu that shows a fact and does nothing when chosen.
    static func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private var button: NSStatusBarButton {
        guard let button = item.button else {
            preconditionFailure("a new status item has no button")
        }
        return button
    }

    private func place(_ view: NSView) {
        view.frame = NSRect(x: 0, y: 0, width: view.frame.width, height: button.bounds.height)
        view.autoresizingMask = [.width, .height]
        button.addSubview(view)
    }

    @objc private func openSettings(_ sender: Any?) {
        showSettings()
    }
}
