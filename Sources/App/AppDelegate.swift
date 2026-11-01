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
    private var statusItem: NSStatusItem?

    override init() {
        paths = .standard
        settingsWindow = SettingsWindowController(title: "MenuMeters Settings")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("launched; config file at \(self.paths.configFile.path)")
        statusItem = makeStatusItem()
    }

    /// A placeholder item with Settings and Quit, until the meters draw their own items.
    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "MM"
        let menu = NSMenu()
        let settings = menu.addItem(
            withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit MenuMeters", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        item.menu = menu
        return item
    }

    @objc private func showSettings(_ sender: Any?) {
        settingsWindow.showWindow(nil)
        // `NSApp.activate()` needs macOS 14.
        NSApp.activate(ignoringOtherApps: true)
    }
}
