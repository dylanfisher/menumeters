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
