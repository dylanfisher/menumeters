import AppKit
import Foundation
import Meters
import Testing

@testable import Interface

@MainActor
@Test func applyingAConfigReshapesTheMeterAndKeepsItsHistory() {
    let meter = CPUMeterController(config: CPUConfig()) {}
    for _ in 0..<3 { meter.tick() }
    let wide = meter.widthPoints

    var config = CPUConfig()
    config.graphWidthPoints = 11
    meter.apply(config)
    #expect(meter.histories.allSatisfy { $0.capacity == 11 && $0.count == 3 })
    // The status item keeps its length in less precision than it is given.
    #expect(abs(meter.widthPoints - (wide - 22)) < 0.01)

    config.showsGraph = false
    meter.apply(config)
    #expect(meter.widthPoints < wide - 22)

    config.isEnabled = false
    meter.apply(config)
    #expect(!meter.isVisible)
}

@MainActor
@Test func theMenuListsTheTopProcesses() async throws {
    let meter = CPUMeterController(config: CPUConfig()) {}
    let menu = NSMenu()
    meter.menuWillOpen(menu)
    #expect(meter.processItems.count == CPUMeterController.topProcessCount)
    #expect(menu.items.contains { $0.title == "Top processes" })
    // The test process works, so it uses some CPU between the two samples.
    let end = Date().addingTimeInterval(0.2)
    var spins = 0
    while Date() < end { spins &+= 1 }
    meter.updateProcessItems()
    let first = try #require(meter.processItems.first)
    #expect(!first.isHidden && first.title.hasSuffix("%"))
    meter.menuDidClose(menu)
    #expect(CPUMeterController.percent(0.123) == "12.3%")
}

@MainActor
@Test func theMenuKeepsEachProcessLabelUntilItCloses() {
    let meter = CPUMeterController(config: CPUConfig()) {}
    let menu = NSMenu()
    meter.menuWillOpen(menu)
    let end = Date().addingTimeInterval(0.2)
    var spins = 0
    while Date() < end { spins &+= 1 }
    meter.updateProcessItems()
    // This process worked, so it is listed and its label is kept for the next tick.
    #expect(meter.processLabels[getpid()] != nil)
    meter.menuDidClose(menu)
    #expect(meter.processLabels.isEmpty)
}
