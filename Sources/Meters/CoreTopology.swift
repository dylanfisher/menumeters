import Foundation
import IOKit

/// Which logical CPUs are performance cores and which are efficiency cores. Intel Macs have one
/// kind, all listed as performance cores. The numbering isn't in kind order: on an M1 Max, CPUs
/// 0–1 are efficiency cores and 2–9 performance cores, so the kinds come from the device tree.
public struct CoreTopology: Sendable, Equatable {
    public var performanceCores: [Int]
    public var efficiencyCores: [Int]

    public init(performanceCores: [Int], efficiencyCores: [Int]) {
        self.performanceCores = performanceCores
        self.efficiencyCores = efficiencyCores
    }

    /// Every core the same kind.
    public static func uniform(coreCount: Int) -> CoreTopology {
        CoreTopology(performanceCores: Array(0..<coreCount), efficiencyCores: [])
    }

    public var coreCount: Int { performanceCores.count + efficiencyCores.count }
    public var hasTwoKinds: Bool { !performanceCores.isEmpty && !efficiencyCores.isEmpty }

    /// Builds the topology from each CPU's `cluster-type` letter, `E` or `P`, keyed by logical
    /// CPU id. Fails when the ids don't cover `0..<coreCount` exactly or a letter is unknown.
    public static func fromClusterTypes(_ types: [Int: Character], coreCount: Int) throws(Failure)
        -> CoreTopology
    {
        guard Set(types.keys) == Set(0..<coreCount) else {
            throw .unexpected("cluster types for CPUs \(types.keys.sorted()), not 0..<\(coreCount)")
        }
        var topology = CoreTopology(performanceCores: [], efficiencyCores: [])
        for (id, type) in types.sorted(by: { $0.key < $1.key }) {
            switch type {
            case "P": topology.performanceCores.append(id)
            case "E": topology.efficiencyCores.append(id)
            default: throw .unexpected("CPU \(id) has cluster type \(type)")
            }
        }
        return topology
    }

    /// The topology of this Mac with `coreCount` logical CPUs. Reads the device tree only when
    /// `hw.nperflevels` says there are two kinds of core.
    public static func current(coreCount: Int) throws(Failure) -> CoreTopology {
        guard let levels = Sysctl.int("hw.nperflevels"), levels > 1 else {
            return .uniform(coreCount: coreCount)
        }
        return try fromClusterTypes(deviceTreeClusterTypes(), coreCount: coreCount)
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
