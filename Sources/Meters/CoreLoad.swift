/// One processor's tick counters, as `host_processor_info` reports them. The counters are 32-bit
/// and wrap, so differences use wrapping subtraction.
public struct CPUTicks: Sendable, Equatable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public static let zero = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
}

/// The share of time a processor, or the average of several, spent in user and system code,
/// each 0...1. Nice time counts as user time, as `top` and Activity Monitor count it.
public struct CoreLoad: Sendable, Equatable {
    public var user: Double
    public var system: Double

    public init(user: Double, system: Double) {
        self.user = user
        self.system = system
    }

    public static let zero = CoreLoad(user: 0, system: 0)

    public var total: Double { user + system }

    /// The load between two samples of one processor; zero when no ticks passed between them.
    public init(from old: CPUTicks, to new: CPUTicks) {
        let user = Double(new.user &- old.user) + Double(new.nice &- old.nice)
        let system = Double(new.system &- old.system)
        let all = user + system + Double(new.idle &- old.idle)
        guard all > 0 else {
            self = .zero
            return
        }
        self.init(user: user / all, system: system / all)
    }

    /// The mean load of the processors at `cores`, indexes into `loads`.
    public static func average(of loads: [CoreLoad], cores: [Int]) -> CoreLoad {
        precondition(!cores.isEmpty, "averaging the load of no cores")
        var user = 0.0
        var system = 0.0
        for core in cores {
            user += loads[core].user
            system += loads[core].system
        }
        let count = Double(cores.count)
        return CoreLoad(user: user / count, system: system / count)
    }
}
