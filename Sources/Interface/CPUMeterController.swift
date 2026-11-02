import AppKit
import Base
import Meters

private let logger = moduleLogger()

/// The CPU meter: its status item, sampler, history and menu. The scheduler calls `tick()`; the
/// menu's live lines update only while it is open.
@MainActor
public final class CPUMeterController: NSObject, ScheduledMeter, NSMenuDelegate {
    private let sampler = CPULoadSampler()
    private let topology: CoreTopology
    private var config: CPUConfig
    /// The cores averaged into each row of the meter: performance then efficiency when the
    /// kinds are grouped, otherwise one row of every core.
    private var rows: [[Int]]
    private(set) var histories: [RingBuffer<CoreLoad>]
    private var view: CPUMeterView
    private let statusItem: MeterStatusItem
    private var loadItems: [(cores: [Int], label: String, item: NSMenuItem)] = []
    private var menuIsOpen = false

    public init(config: CPUConfig, showSettings: @escaping () -> Void) {
        let coreCount = sampler.processorCount
        do {
            topology = try CoreTopology.current(coreCount: coreCount)
        } catch {
            logger.error("\(error.description, privacy: .public); treating every core alike")
            topology = .uniform(coreCount: coreCount)
        }
        self.config = config
        rows = Self.rows(config: config, topology: topology)
        histories = Self.histories(rowCount: rows.count, config: config)
        view = CPUMeterView(config: config, rowCount: rows.count)
        statusItem = MeterStatusItem(
            autosaveName: "CPUMeter", accessibilityLabel: "CPU usage", view: view,
            showSettings: showSettings)
        super.init()
        statusItem.menuDelegate = self
        statusItem.isVisible = config.isEnabled
    }

    /// Whether this Mac has performance and efficiency cores, so grouping them shows two rows.
    public var hasTwoCoreKinds: Bool { topology.hasTwoKinds }

    /// Whether the status item is in the menu bar.
    var isVisible: Bool { statusItem.isVisible }

    /// The status item's width in points.
    var widthPoints: CGFloat { statusItem.widthPoints }

    /// Shows the meter as `config` says, keeping as much history as still fits. The interval is
    /// the scheduler's to apply.
    public func apply(_ config: CPUConfig) {
        let previous = self.config
        self.config = config
        statusItem.isVisible = config.isEnabled
        let newRows = Self.rows(config: config, topology: topology)
        if newRows != rows {
            rows = newRows
            histories = Self.histories(rowCount: rows.count, config: config)
        } else if config.graphWidthPoints != previous.graphWidthPoints {
            histories = histories.map { $0.resized(capacity: config.graphWidthPoints) }
        }
        var display = previous
        display.isEnabled = config.isEnabled
        display.intervalSeconds = config.intervalSeconds
        guard display != config else { return }
        let old = view
        view = CPUMeterView(config: config, rowCount: rows.count)
        statusItem.replace(old, with: view)
        view.show(histories: histories)
    }

    public func tick() {
        sampler.sample()
        for row in rows.indices {
            histories[row].append(CoreLoad.average(of: sampler.loads, cores: rows[row]))
        }
        view.show(histories: histories)
        if menuIsOpen { updateLoadItems() }
    }

    private static func rows(config: CPUConfig, topology: CoreTopology) -> [[Int]] {
        config.groupsCoreKinds && topology.hasTwoKinds
            ? [topology.performanceCores, topology.efficiencyCores]
            : [Array(0..<topology.coreCount)]
    }

    private static func histories(rowCount: Int, config: CPUConfig) -> [RingBuffer<CoreLoad>] {
        (0..<rowCount).map { _ in
            RingBuffer(capacity: config.graphWidthPoints, filler: CoreLoad.zero)
        }
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
        loadItems = []
        menu.addItem(MeterStatusItem.infoItem(SystemStatus.processorName))
        menu.addItem(MeterStatusItem.infoItem(coreSummary))

        if topology.hasTwoKinds {
            addLoadItem(to: menu, cores: topology.performanceCores, label: "Performance cores")
            addLoadItem(to: menu, cores: topology.efficiencyCores, label: "Efficiency cores")
        } else {
            addLoadItem(to: menu, cores: topology.performanceCores, label: "CPU")
        }
        updateLoadItems()

        menu.addItem(
            MeterStatusItem.infoItem("Uptime: \(Self.uptime(SystemStatus.uptimeSeconds()))"))
        let (one, five, fifteen) = SystemStatus.loadAverages
        let averages = [one, five, fifteen].map { String(format: "%.2f", $0) }
        menu.addItem(MeterStatusItem.infoItem("Load average: \(averages.joined(separator: "  "))"))

        menu.addItem(.separator())
        menu.addItem(actionItem("Open Activity Monitor", #selector(openActivityMonitor(_:))))
        statusItem.addClosingItems(to: menu)
    }

    private var coreSummary: String {
        let count = topology.coreCount
        guard topology.hasTwoKinds else { return "\(count) cores" }
        return "\(count) cores: \(topology.performanceCores.count) performance, "
            + "\(topology.efficiencyCores.count) efficiency"
    }

    private func addLoadItem(to menu: NSMenu, cores: [Int], label: String) {
        let item = MeterStatusItem.infoItem(label)
        loadItems.append((cores, label, item))
        menu.addItem(item)
    }

    private func updateLoadItems() {
        for (cores, label, item) in loadItems {
            let load = CoreLoad.average(of: sampler.loads, cores: cores)
            item.title =
                "\(label): \(CPUDrawState.percent(load.user))% user, "
                + "\(CPUDrawState.percent(load.system))% system"
        }
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    /// "3d 4h 5m", or "4h 5m" under a day.
    nonisolated static func uptime(_ seconds: Int) -> String {
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3_600
        let minutes = seconds % 3_600 / 60
        return days > 0 ? "\(days)d \(hours)h \(minutes)m" : "\(hours)h \(minutes)m"
    }

    @objc private func openActivityMonitor(_ sender: Any?) {
        let id = "com.apple.ActivityMonitor"
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            logger.error("no app with bundle id \(id, privacy: .public)")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error {
                logger.error("opening Activity Monitor failed: \(error.localizedDescription)")
            }
        }
    }
}
