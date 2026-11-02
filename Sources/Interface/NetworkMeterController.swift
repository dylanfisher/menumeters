import AppKit
import Base
import Meters

private let logger = moduleLogger()

/// The network meter: its status item, sampler and menu. The scheduler calls `tick()`; the
/// menu's rates update only while it is open.
@MainActor
public final class NetworkMeterController: NSObject, ScheduledMeter, NSMenuDelegate {
    private let sampler = NetworkSampler()
    private var config: NetworkConfig
    private var view: NetworkMeterView
    private let statusItem: MeterStatusItem
    /// The menu lines that change while it is open, with the interface index each is about.
    private var rateItems:
        [(index: Int, rates: NSMenuItem, totals: NSMenuItem, peaks: NSMenuItem)] =
            []
    private var menuIsOpen = false

    public init(config: NetworkConfig, showSettings: @escaping () -> Void) {
        self.config = config
        view = NetworkMeterView(config: config)
        statusItem = MeterStatusItem(
            autosaveName: "NetworkMeter", accessibilityLabel: "Network traffic", view: view,
            showSettings: showSettings)
        super.init()
        statusItem.menuDelegate = self
        statusItem.isVisible = config.isEnabled
    }

    /// Whether the status item is in the menu bar.
    var isVisible: Bool { statusItem.isVisible }

    /// The status item's width in points.
    var widthPoints: CGFloat { statusItem.widthPoints }

    /// Shows the meter as `config` says. The interval is the scheduler's to apply.
    public func apply(_ config: NetworkConfig) {
        let previous = self.config
        self.config = config
        statusItem.isVisible = config.isEnabled
        guard
            config.showsArrows != previous.showsArrows
                || config.showsThroughput != previous.showsThroughput
        else { return }
        let old = view
        view = NetworkMeterView(config: config)
        statusItem.replace(old, with: view)
        showTraffic()
    }

    public func tick() {
        sampler.sample()
        showTraffic()
        if menuIsOpen { updateRateItems() }
    }

    private func showTraffic() {
        view.show(sendRate: sampler.traffic.sendRate, receiveRate: sampler.traffic.receiveRate)
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
        rateItems = []
        let info = NetworkInterfaceInfo.current()
        let traffic = sampler.traffic
        let shown = info.keys.sorted().filter {
            $0 < traffic.interfaces.count && traffic.interfaces[$0].isUp
        }
        if shown.isEmpty { menu.addItem(MeterStatusItem.infoItem("No network connection")) }
        for (position, index) in shown.enumerated() {
            if position > 0 { menu.addItem(.separator()) }
            guard let interface = info[index] else { continue }
            let title = interface.displayName.map { "\($0) (\(interface.name))" } ?? interface.name
            menu.addItem(MeterStatusItem.infoItem(title))
            var lines = interface.ipv4Addresses.map { "IPv4: \($0)" }
            lines += interface.ipv6Addresses.map { "IPv6: \($0)" }
            if let mac = interface.macAddress { lines.append("MAC: \(mac)") }
            let speed = traffic.interfaces[index].linkSpeedBitsPerSecond
            if speed > 0 { lines.append("Link speed: \(Self.bitRate(speed))") }
            for line in lines { menu.addItem(Self.detailItem(line)) }
            let rates = Self.detailItem("")
            let totals = Self.detailItem("")
            let peaks = Self.detailItem("")
            for item in [rates, totals, peaks] { menu.addItem(item) }
            rateItems.append((index, rates, totals, peaks))
        }
        updateRateItems()

        menu.addItem(.separator())
        let open = NSMenuItem(
            title: "Open Network Settings", action: #selector(openNetworkSettings(_:)),
            keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        statusItem.addClosingItems(to: menu)
    }

    private func updateRateItems() {
        let interfaces = sampler.traffic.interfaces
        for (index, rates, totals, peaks) in rateItems where index < interfaces.count {
            let interface = interfaces[index]
            rates.title =
                "Sending \(Self.byteRate(interface.sendRate)), "
                + "receiving \(Self.byteRate(interface.receiveRate))"
            totals.title =
                "Sent \(Self.bytes(interface.sentBytes)), "
                + "received \(Self.bytes(interface.receivedBytes))"
            peaks.title =
                "Peak: sending \(Self.byteRate(interface.peakSendRate)), "
                + "receiving \(Self.byteRate(interface.peakReceiveRate))"
        }
    }

    private static func detailItem(_ title: String) -> NSMenuItem {
        let item = MeterStatusItem.infoItem(title)
        item.indentationLevel = 1
        return item
    }

    /// Bytes in powers of 1,000, as Finder writes them: "1.2 GB".
    nonisolated static func bytes(_ count: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: count), countStyle: .decimal)
    }

    nonisolated static func byteRate(_ bytesPerSecond: Double) -> String {
        bytes(UInt64(max(bytesPerSecond, 0).rounded())) + "/s"
    }

    /// A link speed: "866 Mbit/s", "1 Gbit/s".
    nonisolated static func bitRate(_ bitsPerSecond: UInt64) -> String {
        let value = Double(bitsPerSecond)
        if value >= 1e9 { return String(format: "%g Gbit/s", (value / 1e8).rounded() / 10) }
        if value >= 1e6 { return String(format: "%g Mbit/s", (value / 1e6).rounded()) }
        return String(format: "%g kbit/s", (value / 1e3).rounded())
    }

    @objc private func openNetworkSettings(_ sender: Any?) {
        // System Preferences on macOS 12 and System Settings later both take this URL.
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.network"),
            NSWorkspace.shared.open(url)
        else {
            logger.error("opening Network settings failed")
            return
        }
    }
}
