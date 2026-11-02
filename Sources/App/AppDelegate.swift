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
    private let settingsWindow: SettingsWindowController
    private let scheduler = MeterScheduler()
    private var cpuMeter: CPUMeterController?

    override init() {
        paths = .standard
        settingsWindow = SettingsWindowController(title: "MenuMeters Settings")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("launched; config file at \(self.paths.configFile.path)")
        let config = CPUConfig()
        let cpuMeter = CPUMeterController(config: config) { [weak self] in self?.showSettings() }
        scheduler.add(cpuMeter, intervalSeconds: config.intervalSeconds)
        self.cpuMeter = cpuMeter
        pauseWhileDisplaysSleep()
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
        settingsWindow.showWindow(nil)
        // `NSApp.activate()` needs macOS 14.
        NSApp.activate(ignoringOtherApps: true)
    }
}
