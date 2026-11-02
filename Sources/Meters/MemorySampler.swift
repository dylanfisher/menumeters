import Darwin

/// Reads memory use with `host_statistics64`, the call yujitach's fork uses, into a struct the
/// kernel fills in place, so a sample allocates nothing.
///
/// Not thread-safe; the memory meter owns one and samples it on the main actor.
public final class MemorySampler {
    private let host = mach_host_self()
    private let pageSizeBytes: UInt64
    private let totalBytes: UInt64
    private var info = vm_statistics64()

    /// The memory as of the last call to `sample()`; init takes the first sample.
    public private(set) var stats = MemoryStats.zero

    public init() {
        var pageSize: vm_size_t = 0
        let result = host_page_size(host, &pageSize)
        precondition(result == KERN_SUCCESS, "host_page_size failed: \(result)")
        pageSizeBytes = UInt64(pageSize)
        guard let total = Sysctl.int("hw.memsize") else {
            preconditionFailure("sysctl hw.memsize is missing")
        }
        totalBytes = UInt64(total)
        sample()
    }

    public func sample() {
        // HOST_VM_INFO64_COUNT is a C macro Swift doesn't import.
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        precondition(result == KERN_SUCCESS, "host_statistics64 failed: \(result)")
        stats = MemoryStats(info, pageSizeBytes: pageSizeBytes, totalBytes: totalBytes)
    }

    /// Swap in use and in total, in bytes, for the menu; not read on the tick.
    public static var swap: (usedBytes: UInt64, totalBytes: UInt64) {
        guard let usage = Sysctl.value("vm.swapusage", as: xsw_usage.self, zero: xsw_usage())
        else { preconditionFailure("sysctl vm.swapusage is missing") }
        return (usage.xsu_used, usage.xsu_total)
    }
}
