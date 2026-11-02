import AppKit
import Base
import Meters

/// The memory meter: its status item, sampler and menu. The scheduler calls `tick()`; the menu's
/// numbers update only while it is open.
@MainActor
public final class MemoryMeterController: NSObject, ScheduledMeter, NSMenuDelegate {
    private let sampler = MemorySampler()
    private var config: MemoryConfig
    private var view: MemoryMeterView
    private let statusItem: NSStatusItem
    private let showSettings: () -> Void
    private var statItems: [(label: String, value: (MemoryStats) -> String, item: NSMenuItem)] = []
    private var menuIsOpen = false

    public init(config: MemoryConfig, showSettings: @escaping () -> Void) {
        self.config = config
        view = MemoryMeterView(display: config.display)
        statusItem = NSStatusBar.system.statusItem(withLength: view.frame.width)
        self.showSettings = showSettings
        super.init()

        statusItem.autosaveName = "MemoryMeter"
        button.setAccessibilityLabel("Memory usage")
        place(view)
        statusItem.isVisible = config.isEnabled

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Whether the status item is in the menu bar.
    var isVisible: Bool { statusItem.isVisible }

    /// The status item's width in points.
    var widthPoints: CGFloat { statusItem.length }

    /// Shows the meter as `config` says. The interval is the scheduler's to apply.
    public func apply(_ config: MemoryConfig) {
        let old = self.config
        self.config = config
        statusItem.isVisible = config.isEnabled
        guard config.display != old.display else { return }
        view.removeFromSuperview()
        view = MemoryMeterView(display: config.display)
        statusItem.length = view.frame.width
        place(view)
        view.show(sampler.stats)
    }

    public func tick() {
        sampler.sample()
        view.show(sampler.stats)
        if menuIsOpen { updateStatItems() }
    }

    private var button: NSStatusBarButton {
        guard let button = statusItem.button else {
            preconditionFailure("a new status item has no button")
        }
        return button
    }

    private func place(_ view: MemoryMeterView) {
        view.frame = NSRect(x: 0, y: 0, width: view.frame.width, height: button.bounds.height)
        view.autoresizingMask = [.width, .height]
        button.addSubview(view)
    }

    // MARK: Menu

    public func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        rebuild(menu)
    }

    public func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        statItems = []
        let bytes = Self.bytes
        addStat(to: menu, "Free") { bytes($0.freeBytes) }
        addStat(to: menu, "Used") { bytes($0.usedBytes) }
        addStat(to: menu, "Total") { bytes($0.totalBytes) }
        menu.addItem(.separator())
        addStat(to: menu, "Wired") { bytes($0.wiredBytes) }
        addStat(to: menu, "Active") { bytes($0.activeBytes) }
        addStat(to: menu, "Inactive") { bytes($0.inactiveBytes) }
        addStat(to: menu, "Compressed") { bytes($0.compressedBytes) }
        menu.addItem(.separator())
        addStat(to: menu, "Page-ins") { $0.pageIns.formatted() }
        addStat(to: menu, "Page-outs") { $0.pageOuts.formatted() }
        let swap = MemorySampler.swap
        menu.addItem(
            Self.infoItem("Swap used: \(bytes(swap.usedBytes)) of \(bytes(swap.totalBytes))"))
        updateStatItems()

        menu.addItem(.separator())
        let settings = NSMenuItem(
            title: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(
            withTitle: "Quit MenuMeters", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
    }

    private func addStat(
        to menu: NSMenu, _ label: String, _ value: @escaping (MemoryStats) -> String
    ) {
        let item = Self.infoItem(label)
        statItems.append((label, value, item))
        menu.addItem(item)
    }

    private func updateStatItems() {
        for (label, value, item) in statItems {
            item.title = "\(label): \(value(sampler.stats))"
        }
    }

    /// Bytes as Activity Monitor writes memory sizes, in powers of 1,024: "8.12 GB".
    nonisolated static func bytes(_ count: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: count), countStyle: .memory)
    }

    private static func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func openSettings(_ sender: Any?) {
        showSettings()
    }
}
