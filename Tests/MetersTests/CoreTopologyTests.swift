import Testing

@testable import Meters

@Test func clusterTypesSplitCoresByKindWhateverTheirOrder() throws {
    // An M1 Max: CPUs 0–1 are efficiency cores.
    var types: [Int: Character] = [0: "E", 1: "E"]
    for id in 2..<10 { types[id] = "P" }
    let levels = [
        CoreTopology.Level(name: "Performance", coreCount: 8),
        CoreTopology.Level(name: "Efficiency", coreCount: 2),
    ]
    let topology = try CoreTopology.fromClusterTypes(types, levels: levels, coreCount: 10)
    #expect(
        topology.kinds == [
            .init(name: "Performance", cores: Array(2..<10)),
            .init(name: "Efficiency", cores: [0, 1]),
        ])
    #expect(topology.hasSeveralKinds)
}

@Test func mClusterTypeIsTheSlowerKindOfAnM5Max() throws {
    // An M5 Max: CPUs 0–11 are "M", its Performance cores; 12–17 are "P", its Super cores.
    var types: [Int: Character] = [:]
    for id in 0..<12 { types[id] = "M" }
    for id in 12..<18 { types[id] = "P" }
    let levels = [
        CoreTopology.Level(name: "Super", coreCount: 6),
        CoreTopology.Level(name: "Performance", coreCount: 12),
    ]
    let topology = try CoreTopology.fromClusterTypes(types, levels: levels, coreCount: 18)
    #expect(
        topology.kinds == [
            .init(name: "Super", cores: Array(12..<18)),
            .init(name: "Performance", cores: Array(0..<12)),
        ])
}

@Test func clusterTypesMustCoverEveryCore() {
    #expect(throws: CoreTopology.Failure.self) {
        try CoreTopology.fromClusterTypes([0: "E", 1: "P"], levels: [], coreCount: 3)
    }
}

@Test func anUnknownClusterTypeFails() {
    #expect(throws: CoreTopology.Failure.self) {
        try CoreTopology.fromClusterTypes(
            [0: "X"], levels: [.init(name: "Performance", coreCount: 1)], coreCount: 1)
    }
}

@Test func clusterTypeCountsMustMatchThePerformanceLevels() {
    #expect(throws: CoreTopology.Failure.self) {
        try CoreTopology.fromClusterTypes(
            [0: "P", 1: "E", 2: "E"],
            levels: [
                .init(name: "Performance", coreCount: 2), .init(name: "Efficiency", coreCount: 1),
            ],
            coreCount: 3)
    }
}

@Test func thisMacsTopologyCoversEveryCore() throws {
    let sampler = CPULoadSampler()
    let topology = try CoreTopology.current(coreCount: sampler.processorCount)
    let all = topology.kinds.flatMap(\.cores).sorted()
    #expect(all == Array(0..<sampler.processorCount))
}
