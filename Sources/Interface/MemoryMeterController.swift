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
    private let statusItem: MeterStatusItem
    private var statItems: [(label: String, value: (MemoryStats) -> String, item: NSMenuItem)] = []
    private var menuIsOpen = false

    public init(config: MemoryConfig, showSettings: @escaping () -> Void) {
        self.config = config
        view = MemoryMeterView(display: config.display)
        statusItem = MeterStatusItem(
            autosaveName: "MemoryMeter", accessibilityLabel: "Memory usage", view: view,
            showSettings: showSettings)
        super.init()
        statusItem.menuDelegate = self
        statusItem.isVisible = config.isEnabled
    }

    /// Whether the status item is in the menu bar.
    var isVisible: Bool { statusItem.isVisible }

    /// Whether the meter is on but macOS isn't showing it.
    public var isHiddenByMenuBar: Bool { statusItem.isHiddenByMenuBar }

    /// The status item's width in points.
    var widthPoints: CGFloat { statusItem.widthPoints }

    /// Shows the meter as `config` says. The interval is the scheduler's to apply.
    public func apply(_ config: MemoryConfig) {
        let previous = self.config
        self.config = config
        statusItem.isVisible = config.isEnabled
        guard config.display != previous.display else { return }
        let old = view
        view = MemoryMeterView(display: config.display)
        statusItem.replace(old, with: view)
        view.show(sampler.stats)
    }

    public func tick() {
        sampler.sample()
        view.show(sampler.stats)
        if menuIsOpen { updateStatItems() }
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
            MeterStatusItem.infoItem(
                "Swap used: \(bytes(swap.usedBytes)) of \(bytes(swap.totalBytes))"))
        updateStatItems()

        statusItem.addClosingItems(to: menu)
    }

    private func addStat(
        to menu: NSMenu, _ label: String, _ value: @escaping (MemoryStats) -> String
    ) {
        let item = MeterStatusItem.infoItem(label)
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
}
