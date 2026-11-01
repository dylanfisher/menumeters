import AppKit

/// The settings window, built in code with no nib or storyboard. It edits the config file
/// through the Meters tier; the file stays the source of truth.
@MainActor
public final class SettingsWindowController: NSWindowController {
    public init(title: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = title
        // The controller owns the window. Left at its default of true for a window made in
        // code, AppKit would also release it on close, and the controller's reference would
        // then point at a freed window.
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        preconditionFailure("SettingsWindowController is built in code, not from a nib")
    }
}
