import Foundation
import IOKit

/// Which logical CPUs are of which kind of core, fastest kind first. Intel Macs have one kind.
/// The numbering isn't in kind order: on an M1 Max, CPUs 0–1 are efficiency cores and 2–9
/// performance cores, so the kinds come from the device tree. Each kind's name comes from
/// macOS (`hw.perflevelN.name`), since the names differ by chip: an M5 Max has "Super" and
/// "Performance" cores. See docs/decisions/0010-core-kinds-from-perf-levels.md.
public struct CoreTopology: Sendable, Equatable {
    /// One kind of core: its name as macOS gives it, such as "Efficiency", and its logical CPUs.
    public struct Kind: Sendable, Equatable {
        public var name: String
        public var cores: [Int]

        public init(name: String, cores: [Int]) {
            self.name = name
            self.cores = cores
        }
    }

    /// One macOS performance level: its name and how many logical CPUs it has.
    public struct Level: Sendable, Equatable {
        public var name: String
        public var coreCount: Int

        public init(name: String, coreCount: Int) {
            self.name = name
            self.coreCount = coreCount
        }
    }

    /// Fastest first; one kind, named "CPU", on a Mac whose cores are all alike.
    public var kinds: [Kind]

    public init(kinds: [Kind]) {
        self.kinds = kinds
    }

    /// Every core the same kind.
    public static func uniform(coreCount: Int) -> CoreTopology {
        CoreTopology(kinds: [Kind(name: "CPU", cores: Array(0..<coreCount))])
    }

    public var coreCount: Int { kinds.reduce(0) { $0 + $1.cores.count } }
    public var hasSeveralKinds: Bool { kinds.count > 1 }

    /// The device tree's `cluster-type` letters, fastest first. An M5 Max has P and M; earlier
    /// Apple silicon has P and E.
    static let clusterTypesFastestFirst: [Character] = ["P", "M", "E"]

    /// Builds the topology from each CPU's `cluster-type` letter, keyed by logical CPU id, and
    /// macOS's performance levels, fastest first. The letters present, fastest first, match the
    /// levels in order. Fails when the ids don't cover `0..<coreCount` exactly, a letter is
    /// unknown, or the letters' CPU counts don't match the levels'.
    public static func fromClusterTypes(
        _ types: [Int: Character], levels: [Level], coreCount: Int
    ) throws(Failure) -> CoreTopology {
        guard Set(types.keys) == Set(0..<coreCount) else {
            throw .unexpected("cluster types for CPUs \(types.keys.sorted()), not 0..<\(coreCount)")
        }
        var coresByType: [Character: [Int]] = [:]
        for (id, type) in types.sorted(by: { $0.key < $1.key }) {
            guard clusterTypesFastestFirst.contains(type) else {
                throw .unexpected("CPU \(id) has cluster type \(type)")
            }
            coresByType[type, default: []].append(id)
        }
        let groups = clusterTypesFastestFirst.compactMap { coresByType[$0] }
        guard groups.map(\.count) == levels.map(\.coreCount) else {
            throw .unexpected(
                "cluster types have \(groups.map(\.count)) CPUs, "
                    + "performance levels \(levels.map(\.coreCount))")
        }
        return CoreTopology(
            kinds: zip(levels, groups).map { Kind(name: $0.name, cores: $1) })
    }

    /// The topology of this Mac with `coreCount` logical CPUs. Reads the device tree only when
    /// `hw.nperflevels` says there is more than one kind of core.
    public static func current(coreCount: Int) throws(Failure) -> CoreTopology {
        guard let count = Sysctl.int("hw.nperflevels"), count > 1 else {
            return .uniform(coreCount: coreCount)
        }
        let levels = try (0..<count).map { (level) throws(Failure) in
            guard let name = Sysctl.string("hw.perflevel\(level).name"),
                let cores = Sysctl.int("hw.perflevel\(level).logicalcpu")
            else { throw .unexpected("no name or CPU count for performance level \(level)") }
            return Level(name: name, coreCount: cores)
        }
        return try fromClusterTypes(deviceTreeClusterTypes(), levels: levels, coreCount: coreCount)
    }

    public enum Failure: Error, CustomStringConvertible {
        case unexpected(String)

        public var description: String {
            switch self {
            case .unexpected(let detail): "unexpected CPU topology: \(detail)"
            }
        }
    }

    /// The children of `IODeviceTree:/cpus`, each with `logical-cpu-id` and `cluster-type`.
    private static func deviceTreeClusterTypes() throws(Failure) -> [Int: Character] {
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard cpus != IO_OBJECT_NULL else { throw .unexpected("no IODeviceTree:/cpus") }
        defer { IOObjectRelease(cpus) }
        var iterator: io_iterator_t = IO_OBJECT_NULL
        let result = IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &iterator)
        guard result == KERN_SUCCESS else { throw .unexpected("child iterator failed: \(result)") }
        defer { IOObjectRelease(iterator) }

        var types: [Int: Character] = [:]
        while case let cpu = IOIteratorNext(iterator), cpu != IO_OBJECT_NULL {
            defer { IOObjectRelease(cpu) }
            guard let id = property(cpu, "logical-cpu-id") as? NSNumber,
                let type = property(cpu, "cluster-type") as? Data, let letter = type.first
            else { throw .unexpected("a CPU in the device tree lacks its id or cluster type") }
            types[id.intValue] = Character(Unicode.Scalar(letter))
        }
        return types
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }
}
