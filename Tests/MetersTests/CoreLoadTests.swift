import Foundation
import Testing

@testable import Meters

@Test func loadIsTheShareOfTicksSpentInUserAndSystemCode() {
    let old = CPUTicks(user: 100, system: 50, idle: 800, nice: 10)
    let new = CPUTicks(user: 130, system: 60, idle: 850, nice: 20)
    // 40 user (30 user + 10 nice), 10 system, 50 idle.
    let load = CoreLoad(from: old, to: new)
    #expect(load == CoreLoad(user: 0.4, system: 0.1))
}

@Test func loadSurvivesCountersWrapping() {
    let old = CPUTicks(user: .max - 9, system: 0, idle: .max - 9, nice: 0)
    let new = CPUTicks(user: 10, system: 0, idle: 10, nice: 0)
    #expect(CoreLoad(from: old, to: new) == CoreLoad(user: 0.5, system: 0))
}

@Test func noTicksBetweenSamplesIsNoLoad() {
    let ticks = CPUTicks(user: 5, system: 5, idle: 5, nice: 5)
    #expect(CoreLoad(from: ticks, to: ticks) == .zero)
}

@Test func averageTakesOnlyTheNamedCores() {
    let loads = [
        CoreLoad(user: 1, system: 0), CoreLoad(user: 0.5, system: 0.5),
        CoreLoad(user: 0, system: 0),
    ]
    #expect(CoreLoad.average(of: loads, cores: [0, 1]) == CoreLoad(user: 0.75, system: 0.25))
}

@Test func theSamplerReportsALoadForEveryProcessor() {
    let sampler = CPULoadSampler()
    sampler.sample()
    #expect(sampler.processorCount == ProcessInfo.processInfo.processorCount)
    for load in sampler.loads {
        #expect(load.user >= 0 && load.system >= 0 && load.total <= 1.0001)
    }
}
