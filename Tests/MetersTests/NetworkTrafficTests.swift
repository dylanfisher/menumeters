import Darwin
import Testing

@testable import Meters

private let up = IFF_UP | IFF_RUNNING

private func record(
    _ traffic: inout NetworkTraffic, index: Int, flags: Int32 = up, type: Int32 = IFT_ETHER,
    received: UInt64, sent: UInt64
) {
    traffic.record(
        index: index, flags: flags, type: type, linkSpeedBitsPerSecond: 1_000_000_000,
        receivedBytes: received, sentBytes: sent)
}

@Test func ratesAreBytesPerSecondSinceTheLastSample() {
    var traffic = NetworkTraffic()
    traffic.begin(elapsedSeconds: 0)
    record(&traffic, index: 4, received: 1_000, sent: 500)
    traffic.end()
    #expect(traffic.receiveRate == 0)
    traffic.begin(elapsedSeconds: 2)
    record(&traffic, index: 4, received: 5_000, sent: 1_500)
    traffic.end()
    #expect(traffic.interfaces[4].receiveRate == 2_000)
    #expect(traffic.interfaces[4].sendRate == 500)
    #expect(traffic.receiveRate == 2_000 && traffic.sendRate == 500)
    traffic.begin(elapsedSeconds: 2)
    record(&traffic, index: 4, received: 5_000, sent: 1_500)
    traffic.end()
    #expect(traffic.interfaces[4].receiveRate == 0)
    #expect(traffic.interfaces[4].peakReceiveRate == 2_000)
}

@Test func theMeterCountsOnlyEthernetTypeInterfacesThatAreUp() {
    var traffic = NetworkTraffic()
    traffic.begin(elapsedSeconds: 0)
    record(&traffic, index: 1, flags: up | IFF_LOOPBACK, type: IFT_LOOP, received: 0, sent: 0)
    record(&traffic, index: 14, received: 0, sent: 0)
    record(&traffic, index: 18, type: IFT_OTHER, received: 0, sent: 0)
    record(&traffic, index: 22, flags: 0, received: 0, sent: 0)
    traffic.end()
    traffic.begin(elapsedSeconds: 1)
    record(&traffic, index: 1, flags: up | IFF_LOOPBACK, type: IFT_LOOP, received: 900, sent: 900)
    record(&traffic, index: 14, received: 100, sent: 10)
    // A VPN tunnel carries again what the Wi-Fi interface carries.
    record(&traffic, index: 18, type: IFT_OTHER, received: 90, sent: 9)
    record(&traffic, index: 22, flags: 0, received: 50, sent: 50)
    traffic.end()
    #expect(traffic.receiveRate == 100 && traffic.sendRate == 10)
}

@Test func anInterfaceThatGoesOrResetsStartsOver() {
    var traffic = NetworkTraffic()
    traffic.begin(elapsedSeconds: 0)
    record(&traffic, index: 40, received: 1_000, sent: 1_000)
    traffic.end()
    #expect(traffic.interfaces.count > 40)
    traffic.begin(elapsedSeconds: 1)
    record(&traffic, index: 40, received: 10, sent: 10)
    traffic.end()
    #expect(traffic.interfaces[40].receiveRate == 0)
    traffic.begin(elapsedSeconds: 1)
    traffic.end()
    #expect(!traffic.interfaces[40].isPresent && traffic.interfaces[40].receivedBytes == 0)
}

@Test func theSamplerAndInfoReadThisMacsInterfaces() {
    let sampler = NetworkSampler()
    sampler.sample()
    let loopback = Int(if_nametoindex("lo0"))
    #expect(sampler.traffic.interfaces[loopback].isPresent)
    #expect(!sampler.traffic.interfaces[loopback].isCounted)
    let info = NetworkInterfaceInfo.current()
    #expect(info[loopback]?.ipv4Addresses.contains("127.0.0.1") == true)
    #expect(info.values.contains { $0.macAddress?.count == 17 })
}
