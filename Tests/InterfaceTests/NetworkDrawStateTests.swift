import Meters
import Testing

@testable import Interface

private func throughput() -> NetworkConfig {
    var config = NetworkConfig()
    config.showsArrows = false
    config.showsThroughput = true
    return config
}

@Test func ratesAreWrittenInTwoOrThreeDigits() {
    let text = { NetworkDrawState.text(NetworkDrawState.rate($0)) }
    #expect(text(0) == "0B")
    #expect(text(512) == "512B")
    #expect(text(999.6) == "1.0K")
    #expect(text(1_234) == "1.2K")
    #expect(text(12_345) == "12K")
    #expect(text(123_456_789) == "123M")
    #expect(text(2_500_000_000) == "2.5G")
}

@Test func anArrowLightsOnlyAboveAKilobyteASecond() {
    let state = NetworkDrawState(sendRate: 999, receiveRate: 5_000, config: NetworkConfig())
    #expect(!state.isSending && state.isReceiving)
    #expect(state.receive == .init())
}

@Test func aRateChangeTheTextDoesntShowDrawsNothingNew() {
    let before = NetworkDrawState(sendRate: 12_340, receiveRate: 0, config: throughput())
    let after = NetworkDrawState(sendRate: 12_390, receiveRate: 0, config: throughput())
    #expect(before == after)
    #expect(!before.isSending)
    let moved = NetworkDrawState(sendRate: 13_000, receiveRate: 0, config: throughput())
    #expect(before != moved)
}

@Test func linkSpeedsReadInBitsPerSecond() {
    #expect(NetworkMeterController.bitRate(608_400_000) == "608 Mbit/s")
    #expect(NetworkMeterController.bitRate(1_000_000_000) == "1 Gbit/s")
    #expect(NetworkMeterController.bitRate(2_500_000_000) == "2.5 Gbit/s")
}

@MainActor
@Test func theNetworkMeterAddsThroughputAndHides() {
    let meter = NetworkMeterController(config: NetworkConfig()) {}
    meter.tick()
    let arrows = meter.widthPoints
    var config = NetworkConfig()
    config.showsThroughput = true
    meter.apply(config)
    #expect(meter.widthPoints > arrows)
    config.isEnabled = false
    meter.apply(config)
    #expect(!meter.isVisible)
}
