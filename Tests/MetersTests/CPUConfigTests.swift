import Testing

@testable import Meters

@Test func theCPUMeterTicksEveryTwoSecondsByDefault() {
    let config = CPUConfig()
    #expect(config.intervalSeconds == 2)
    #expect(CPUConfig.intervalSecondsRange.contains(config.intervalSeconds))
}
