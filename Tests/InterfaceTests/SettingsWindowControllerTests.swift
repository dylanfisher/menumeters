import AppKit
import Testing

@testable import Interface

@MainActor
@Test func theControllerBuildsATitledWindowThatSurvivesClosing() throws {
    let controller = SettingsWindowController(title: "Test Settings")
    let window = try #require(controller.window)
    #expect(window.title == "Test Settings")
    #expect(window.styleMask.contains(.titled))
    #expect(!window.isReleasedWhenClosed)
}
