import Darwin

/// Reads per-processor load with `host_processor_info`, the call yujitach's fork uses. Keeps the
/// previous counters and the loads in arrays sized once at init, so a sample allocates nothing on
/// the Swift heap. The kernel hands back a fresh VM buffer on each call, which is freed before
/// returning.
///
/// Not thread-safe; the CPU meter owns one and samples it on the main actor.
public final class CPULoadSampler {
    private let host = mach_host_self()
    private var previous: [CPUTicks]

    /// Each processor's load between the last two calls to `sample()`, indexed by logical CPU
    /// id. Right after init, the load since boot.
    public private(set) var loads: [CoreLoad]

    /// Sizes the arrays from the first call to `host_processor_info`, which also takes the first
    /// sample.
    public init() {
        previous = []
        loads = []
        sample()
    }

    public var processorCount: Int { loads.count }

    public func sample() {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(
            host, PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else {
            preconditionFailure("host_processor_info failed: \(result)")
        }
        defer {
            vm_deallocate(
                mach_task_self_, vm_address_t(bitPattern: info),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        if loads.isEmpty {
            previous = Array(repeating: .zero, count: Int(processorCount))
            loads = Array(repeating: .zero, count: Int(processorCount))
        }
        // Processors don't come and go while the app runs on any Mac it supports.
        precondition(Int(processorCount) == loads.count, "the processor count changed")
        let stride = Int(CPU_STATE_MAX)
        for core in 0..<loads.count {
            let base = core * stride
            let ticks = CPUTicks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            loads[core] = CoreLoad(from: previous[core], to: ticks)
            previous[core] = ticks
        }
    }
}
