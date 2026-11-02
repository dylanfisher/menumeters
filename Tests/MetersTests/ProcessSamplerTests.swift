import Foundation
import Testing

@testable import Meters

@Test func theTopProcessesAreTheLargestSharesOfTheTime() {
    let second: UInt64 = 1_000_000_000
    let previous: [Int32: UInt64] = [1: 0, 2: 0, 3: 0, 4: 5 * second]
    // 5 started between the samples, and 4's time is the same: neither is listed.
    let current: [Int32: UInt64] = [
        1: second / 2, 2: 2 * second, 3: second / 2, 4: 5 * second, 5: second,
    ]
    let top = ProcessSampler.top(
        previous: previous, current: current, elapsedNanoseconds: second, count: 2)
    #expect(top.map(\.pid) == [2, 1])
    #expect(top.map(\.share) == [2, 0.5])
    #expect(
        ProcessSampler.top(previous: previous, current: current, elapsedNanoseconds: 0, count: 5)
            .isEmpty)
}

@Test func theSamplerSeesThisProcessWorking() {
    let sampler = ProcessSampler()
    #expect(sampler.sample(top: 5).isEmpty)
    // Busy for a tenth of a second, so this process is near the top.
    let end = Date().addingTimeInterval(0.1)
    var spins = 0
    while Date() < end { spins &+= 1 }
    let top = sampler.sample(top: 50)
    let me = top.first { $0.pid == getpid() }
    #expect(me != nil)
    #expect((me?.share ?? 0) > 0.3 && (me?.share ?? 0) < 1.5)
}
