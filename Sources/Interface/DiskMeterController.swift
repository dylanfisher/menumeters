import AppKit
import Base
import Meters
import UniformTypeIdentifiers

private let logger = moduleLogger()

/// The disk meter: its status item, activity sampler and volume menu. The scheduler calls
/// `tick()`. The volumes come from `VolumeStore` off the main thread: the menu shows the last
/// list at once and updates when a fresh one arrives, and mounts and unmounts refresh it.
@MainActor
public final class DiskMeterController: NSObject, ScheduledMeter, NSMenuDelegate {
    private let sampler = DiskActivitySampler()
    private let volumeStore: VolumeStore
    private let view = DiskMeterView()
    private let statusItem: MeterStatusItem
    private(set) var volumes: [Volume] = []
    /// The menu while it is open, so a fresh volume list can show in it.
    private var openMenu: NSMenu?

    public init(config: DiskConfig, volumeStore: VolumeStore, showSettings: @escaping () -> Void) {
        self.volumeStore = volumeStore
        statusItem = MeterStatusItem(
            autosaveName: "DiskMeter", accessibilityLabel: "Disk activity", view: view,
            showSettings: showSettings)
        super.init()
        statusItem.menuDelegate = self
        statusItem.isVisible = config.isEnabled
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            center.addObserver(
                self, selector: #selector(volumesChanged(_:)), name: name, object: nil)
        }
        Task { await refreshVolumes() }
    }

    /// Whether the status item is in the menu bar.
    var isVisible: Bool { statusItem.isVisible }

    /// Shows the meter as `config` says. The interval is the scheduler's to apply.
    public func apply(_ config: DiskConfig) {
        statusItem.isVisible = config.isEnabled
    }

    public func tick() {
        sampler.sample()
        view.show(sampler.activity)
    }

    /// Reads the volumes again, and shows them if the menu is open.
    func refreshVolumes() async {
        let fresh = await volumeStore.volumes()
        guard fresh != volumes else { return }
        volumes = fresh
        if let openMenu { rebuild(openMenu) }
    }

    @objc private func volumesChanged(_ notification: Notification) {
        Task { await refreshVolumes() }
    }

    // MARK: Menu

    public func menuWillOpen(_ menu: NSMenu) {
        openMenu = menu
        rebuild(menu)
        // Free space changes as files are written, so the list is read again for an open menu.
        Task { await refreshVolumes() }
    }

    public func menuDidClose(_ menu: NSMenu) {
        openMenu = nil
    }

    func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        if volumes.isEmpty { menu.addItem(MeterStatusItem.infoItem("No volumes")) }
        let icon = NSWorkspace.shared.icon(for: .volume)
        icon.size = NSSize(width: 16, height: 16)
        for (index, volume) in volumes.enumerated() {
            let open = NSMenuItem(
                title: Self.title(volume), action: #selector(openVolume(_:)), keyEquivalent: "")
            open.target = self
            open.tag = index
            open.image = icon
            menu.addItem(open)
            guard volume.isEjectable else { continue }
            // Shown in place of the item above while ⌥ is held.
            let eject = NSMenuItem(
                title: "Eject \(volume.name)", action: #selector(ejectVolume(_:)),
                keyEquivalent: "")
            eject.target = self
            eject.tag = index
            eject.image = icon
            eject.isAlternate = true
            eject.keyEquivalentModifierMask = .option
            menu.addItem(eject)
        }
        statusItem.addClosingItems(to: menu)
    }

    /// "Macintosh HD: 245 GB free of 994 GB".
    nonisolated static func title(_ volume: Volume) -> String {
        let free = ByteCountFormatter.string(
            fromByteCount: volume.availableBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: volume.totalBytes, countStyle: .file)
        return "\(volume.name): \(free) free of \(total)"
    }

    @objc private func openVolume(_ sender: NSMenuItem) {
        guard volumes.indices.contains(sender.tag) else { return }
        NSWorkspace.shared.open(volumes[sender.tag].url)
    }

    @objc private func ejectVolume(_ sender: NSMenuItem) {
        guard volumes.indices.contains(sender.tag) else { return }
        let volume = volumes[sender.tag]
        let store = volumeStore
        Task {
            do throws(VolumeStore.EjectFailed) {
                try await store.eject(volume)
            } catch {
                logger.error("ejecting a volume failed: \(error.reason, privacy: .public)")
                let alert = NSAlert()
                alert.messageText = "\(volume.name) couldn't be ejected."
                alert.informativeText = error.reason
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
            await refreshVolumes()
        }
    }
}
