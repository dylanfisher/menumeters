import AppKit

// A top-level main.swift rather than @main, so command-line modes can be parsed here before
// NSApplication starts.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
