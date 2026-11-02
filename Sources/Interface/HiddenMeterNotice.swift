import AppKit
import Base
import os

private let logger = moduleLogger()

/// Tells the user, once per launch, when macOS hides meters in a crowded menu bar. It checks
/// when the menu bar or the screens change, not on the tick: when the screens are rearranged,
/// when another app comes to the front with its own menus, and when a meter is switched on.
/// Yujitach's fork checks every meter on every tick with `CGWindowListCreate`, which on macOS 27
/// no longer lists status items at all.
@MainActor
public final class HiddenMeterNotice: NSObject {
    /// A meter's name for the notice, and whether it is hidden now.
    public typealias Meter = (name: String, isHidden: () -> Bool)

    private let meters: () -> [Meter]
    private let showSettings: () -> Void
    private var pending: Task<Void, Never>?
    private var hasShown = false

    /// How long after a change the menu bar is checked: it lays out after an app activates.
    static let settleNanoseconds: UInt64 = 2_000_000_000

    public init(meters: @escaping () -> [Meter], showSettings: @escaping () -> Void) {
        self.meters = meters
        self.showSettings = showSettings
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed(_:)),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(changed(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    /// Checks once the menu bar has settled, unless the notice has been shown this launch.
    public func scheduleCheck() {
        guard !hasShown else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.settleNanoseconds)
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    @objc private func changed(_ notification: Notification) {
        scheduleCheck()
    }

    private func check() {
        guard !hasShown, Self.menuBarIsShown() else { return }
        let hidden = meters().filter { $0.isHidden() }.map(\.name)
        guard !hidden.isEmpty else { return }
        logger.info("hidden by the menu bar: \(hidden.joined(separator: ", "), privacy: .public)")
        hasShown = true
        let alert = NSAlert()
        alert.messageText = Self.message(hidden: hidden)
        alert.informativeText =
            "The menu bar is too full to show them. Hold Command and drag them to the right, "
            + "quit apps with menu bar items, or turn some meters off in MenuMeters Settings."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Settings")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { showSettings() }
    }

    /// "macOS is hiding the CPU and Disk meters".
    nonisolated static func message(hidden names: [String]) -> String {
        let list: String
        switch names.count {
        case 1: list = names[0]
        case 2: list = "\(names[0]) and \(names[1])"
        default: list = names.dropLast().joined(separator: ", ") + ", and \(names.last ?? "")"
        }
        return "macOS is hiding the \(list) meter\(names.count == 1 ? "" : "s")"
    }

    /// Whether the menu bar holds its place on screen, so a meter missing from it is hidden by
    /// crowding: not while it hides itself until the pointer reaches the top, and not while a
    /// full-screen window is in front.
    private static func menuBarIsShown() -> Bool {
        guard let screen = NSScreen.screens.first else { return false }
        if screen.visibleFrame.maxY >= screen.frame.maxY { return false }
        let size = screen.frame.size
        let windows =
            CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let fullScreen = windows.contains { window in
            guard window[kCGWindowLayer as String] as? Int == 0,
                let bounds = window[kCGWindowBounds as String] as? [String: CGFloat]
            else { return false }
            return bounds["Width"] == size.width && bounds["Height"] == size.height
        }
        return !fullScreen
    }
}
