import Testing

@testable import Meters

@Test func clusterTypesSplitCoresByKindWhateverTheirOrder() throws {
    // An M1 Max: CPUs 0–1 are efficiency cores.
    var types: [Int: Character] = [0: "E", 1: "E"]
    for id in 2..<10 { types[id] = "P" }
    let topology = try CoreTopology.fromClusterTypes(types, coreCount: 10)
    #expect(topology.efficiencyCores == [0, 1])
    #expect(topology.performanceCores == Array(2..<10))
    #expect(topology.hasTwoKinds)
}

@Test func clusterTypesMustCoverEveryCore() {
    #expect(throws: CoreTopology.Failure.self) {
        try CoreTopology.fromClusterTypes([0: "E", 1: "P"], coreCount: 3)
    }
}

@Test func anUnknownClusterTypeFails() {
    #expect(throws: CoreTopology.Failure.self) {
        try CoreTopology.fromClusterTypes([0: "X"], coreCount: 1)
    }
}

@Test func thisMacsTopologyCoversEveryCore() throws {
    let sampler = CPULoadSampler()
    let topology = try CoreTopology.current(coreCount: sampler.processorCount)
    let all = (topology.performanceCores + topology.efficiencyCores).sorted()
    #expect(all == Array(0..<sampler.processorCount))
}
