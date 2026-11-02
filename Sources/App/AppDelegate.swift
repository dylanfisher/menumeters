import AppKit
import Base
import Interface
import Meters
import os

private let logger = moduleLogger()

/// The composition root: builds every long-lived object and passes each one what it needs
/// through its initializer. A new service is made here, so every dependency is visible in one
/// file and no type reaches for a singleton.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let paths: AppPaths
    private let store: ConfigStore
    private let scheduler = MeterScheduler()
    private let volumeStore = VolumeStore()
    /// Built from the first state of the config file, which is read off the main thread.
    private var cpuMeter: CPUMeterController?
    private var memoryMeter: MemoryMeterController?
    private var networkMeter: NetworkMeterController?
    private var diskMeter: DiskMeterController?
    private var settingsWindow: SettingsWindowController?
    private var hiddenMeterNotice: HiddenMeterNotice?
    /// The last save to the config file; each save waits for the one before, so the file ends
    /// with the last change made.
    private var saving: Task<Void, Never>?

    override init() {
        paths = .standard
        store = ConfigStore(file: paths.configFile)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("launched; config file at \(self.paths.configFile.path)")
        pauseWhileDisplaysSleep()
        let store = store
        Task {
            await store.start()
            for await state in store.states { apply(state) }
        }
    }

    /// Opening the app again while it runs, as from the Finder, shows the settings: the only
    /// way to them when every meter is off.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return false
    }

    /// Applies a state of the config file: to the meters, and to the settings window.
    private func apply(_ state: ConfigStore.State) {
        guard let settingsWindow else {
            start(with: state)
            return
        }
        apply(state.config)
        settingsWindow.show(state)
    }

    private func start(with state: ConfigStore.State) {
        let config = state.config
        let cpuMeter = CPUMeterController(config: config.cpu) { [weak self] in
            self?.showSettings()
        }
        scheduler.add(cpuMeter, intervalSeconds: config.cpu.scheduledIntervalSeconds)
        self.cpuMeter = cpuMeter
        let memoryMeter = MemoryMeterController(config: config.memory) { [weak self] in
            self?.showSettings()
        }
        scheduler.add(memoryMeter, intervalSeconds: config.memory.scheduledIntervalSeconds)
        self.memoryMeter = memoryMeter
        let networkMeter = NetworkMeterController(config: config.network) { [weak self] in
            self?.showSettings()
        }
        scheduler.add(networkMeter, intervalSeconds: config.network.scheduledIntervalSeconds)
        self.networkMeter = networkMeter
        let diskMeter = DiskMeterController(config: config.disk, volumeStore: volumeStore) {
            [weak self] in self?.showSettings()
        }
        scheduler.add(diskMeter, intervalSeconds: config.disk.scheduledIntervalSeconds)
        self.diskMeter = diskMeter
        hiddenMeterNotice = HiddenMeterNotice(
            meters: { [weak self] in self?.meterVisibility() ?? [] },
            showSettings: { [weak self] in self?.showSettings() })
        hiddenMeterNotice?.scheduleCheck()
        settingsWindow = SettingsWindowController(
            title: "MenuMeters Settings", state: state, configFile: paths.configFile,
            hasTwoCoreKinds: cpuMeter.hasTwoCoreKinds
        ) { [weak self] config in self?.settingsChanged(config) }
    }

    private func apply(_ config: AppConfig) {
        guard let cpuMeter, let memoryMeter, let networkMeter, let diskMeter else {
            preconditionFailure("applying a config before the meters exist")
        }
        cpuMeter.apply(config.cpu)
        scheduler.setInterval(of: cpuMeter, seconds: config.cpu.scheduledIntervalSeconds)
        memoryMeter.apply(config.memory)
        scheduler.setInterval(of: memoryMeter, seconds: config.memory.scheduledIntervalSeconds)
        networkMeter.apply(config.network)
        scheduler.setInterval(of: networkMeter, seconds: config.network.scheduledIntervalSeconds)
        diskMeter.apply(config.disk)
        scheduler.setInterval(of: diskMeter, seconds: config.disk.scheduledIntervalSeconds)
    }

    private func meterVisibility() -> [HiddenMeterNotice.Meter] {
        guard let cpuMeter, let memoryMeter, let networkMeter, let diskMeter else { return [] }
        return [
            ("CPU", { cpuMeter.isHiddenByMenuBar }), ("Memory", { memoryMeter.isHiddenByMenuBar }),
            ("Network", { networkMeter.isHiddenByMenuBar }),
            ("Disk", { diskMeter.isHiddenByMenuBar }),
        ]
    }

    private func settingsChanged(_ config: AppConfig) {
        apply(config)
        // A meter switched on may not fit.
        hiddenMeterNotice?.scheduleCheck()
        let previous = saving
        let store = store
        saving = Task {
            await previous?.value
            await store.save(config)
        }
    }

    /// Nothing reads the menu bar while the displays sleep. Yujitach's fork keeps sampling.
    private func pauseWhileDisplaysSleep() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(displaysDidSleep(_:)),
            name: NSWorkspace.screensDidSleepNotification, object: nil)
        center.addObserver(
            self, selector: #selector(displaysDidWake(_:)),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    @objc private func displaysDidSleep(_ notification: Notification) {
        scheduler.pause()
    }

    @objc private func displaysDidWake(_ notification: Notification) {
        scheduler.resume()
    }

    private func showSettings() {
        guard let settingsWindow else { return }
        settingsWindow.showWindow(nil)
        // `NSApp.activate()` needs macOS 14.
        NSApp.activate(ignoringOtherApps: true)
    }
}
