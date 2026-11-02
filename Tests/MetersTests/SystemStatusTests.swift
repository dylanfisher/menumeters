import Testing

@testable import Meters

@Test func theMacHasANameAnUptimeAndLoadAverages() {
    #expect(!SystemStatus.processorName.isEmpty)
    #expect(SystemStatus.uptimeSeconds() > 0)
    let (one, five, fifteen) = SystemStatus.loadAverages
    #expect(one >= 0 && five >= 0 && fifteen >= 0)
}
