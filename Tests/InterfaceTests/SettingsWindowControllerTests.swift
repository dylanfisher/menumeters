import AppKit
import Meters
import Testing

@testable import Interface

private let file = URL(fileURLWithPath: "/tmp/settings-test/config.json")
private let good = ConfigStore.State(config: AppConfig(), problem: nil, isFileBroken: false)

@MainActor
private func controller(
    _ state: ConfigStore.State = good, onChange: @escaping (AppConfig) -> Void = { _ in }
) -> SettingsWindowController {
    SettingsWindowController(
        title: "Test Settings", state: state, configFile: file, hasTwoCoreKinds: true,
        onChange: onChange)
}

@MainActor
@Test func theControllerBuildsATitledWindowThatSurvivesClosing() throws {
    let window = try #require(controller().window)
    #expect(window.title == "Test Settings")
    #expect(window.styleMask.contains(.titled))
    #expect(!window.isReleasedWhenClosed)
}

@MainActor
@Test func aControlChangeSendsTheWholeConfig() {
    var sent: [AppConfig] = []
    let settings = controller { sent.append($0) }
    let tab = settings.cpuTab
    tab.percentBox.performClick(nil)
    #expect(sent.last?.cpu.showsPercent == false)
    #expect(sent.last?.cpu.showsGraph == true)
    // The graph is now all the meter shows, so it can't be turned off too.
    #expect(!tab.graphBox.isEnabled)
    tab.widthSlider.integerValue = 60
    tab.widthSlider.sendAction(tab.widthSlider.action, to: tab.widthSlider.target)
    #expect(sent.last?.cpu.graphWidthPoints == 60)
    #expect(sent.last?.cpu.showsPercent == false)
    #expect(tab.widthLabel.stringValue == "60 px")
}

@MainActor
@Test func turningTheMeterOffLocksItsOtherSettings() {
    var sent: [AppConfig] = []
    let settings = controller { sent.append($0) }
    let tab = settings.cpuTab
    tab.enabledBox.performClick(nil)
    #expect(sent.last?.cpu.isEnabled == false)
    #expect(!tab.intervalSlider.isEnabled && !tab.percentBox.isEnabled)
}

@MainActor
@Test func aHandEditShowsInTheControls() {
    let settings = controller()
    var config = AppConfig()
    config.cpu.intervalSeconds = 5
    settings.show(.init(config: config, problem: nil, isFileBroken: false))
    #expect(settings.cpuTab.intervalSlider.doubleValue == 5)
    #expect(settings.cpuTab.intervalLabel.stringValue == "5 s")
    #expect(settings.problemLabel.isHidden)
}

@MainActor
@Test func aBrokenFileLocksTheControlsAndSaysWhy() {
    let problem = ConfigError("cpu.intervalSeconds must be a number from 0.5 to 10, not 30")
    let settings = controller(.init(config: AppConfig(), problem: problem, isFileBroken: true))
    #expect(!settings.cpuTab.enabledBox.isEnabled)
    #expect(!settings.problemLabel.isHidden)
    #expect(settings.problemLabel.stringValue.hasSuffix("not 30."))
    settings.show(good)
    #expect(settings.cpuTab.enabledBox.isEnabled)
    #expect(settings.problemLabel.isHidden)
}

@MainActor
@Test func theMemoryTabSendsItsDisplayAndWholeSeconds() {
    var sent: [AppConfig] = []
    let settings = controller { sent.append($0) }
    let tab = settings.memoryTab
    _ = tab.view
    tab.displayPopUp.selectItem(at: 1)
    tab.displayPopUp.sendAction(tab.displayPopUp.action, to: tab.displayPopUp.target)
    #expect(sent.last?.memory.display == .number)
    tab.intervalSlider.doubleValue = 4.4
    tab.intervalSlider.sendAction(tab.intervalSlider.action, to: tab.intervalSlider.target)
    #expect(sent.last?.memory.intervalSeconds == 4)
    #expect(sent.last?.memory.display == .number)
    settings.show(.init(config: AppConfig(), problem: ConfigError("x"), isFileBroken: true))
    #expect(!tab.displayPopUp.isEnabled)
}

@MainActor
@Test func theNetworkTabKeepsOneDisplayOnAndHalfSeconds() {
    var sent: [AppConfig] = []
    let settings = controller { sent.append($0) }
    let tab = settings.networkTab
    _ = tab.view
    // Arrows alone are on by default, so they can't be turned off until throughput is on.
    #expect(!tab.arrowsBox.isEnabled)
    tab.throughputBox.performClick(nil)
    #expect(sent.last?.network.showsThroughput == true)
    #expect(tab.arrowsBox.isEnabled)
    tab.intervalSlider.doubleValue = 3.3
    tab.intervalSlider.sendAction(tab.intervalSlider.action, to: tab.intervalSlider.target)
    #expect(sent.last?.network.intervalSeconds == 3.5)
}
