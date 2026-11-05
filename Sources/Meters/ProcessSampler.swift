import Darwin

/// A process and the CPU it used between two samples.
public struct ProcessLoad: Sendable, Equatable {
    public var pid: Int32
    /// The kernel's name for it, up to 32 characters; the menu prefers an app's own name.
    public var name: String
    /// CPU time over wall time, as Activity Monitor counts it: 1 is one core busy.
    public var share: Double

    public init(pid: Int32, name: String, share: Double) {
        self.pid = pid
        self.name = name
        self.share = share
    }
}

/// Finds the processes using the most CPU with `proc_pid_rusage`, where yujitach's fork parses
/// the output of `/usr/bin/top`. Only the user's own processes can be read without root, so
/// system processes such as WindowServer are left out (docs/decisions/0006-top-processes.md).
///
/// Sampled only while the CPU menu is open. It lists only the user's processes, the ones it can
/// read, and keeps its buffers from one sample to the next. Not thread-safe; the CPU meter owns
/// one and samples it on the main actor.
public final class ProcessSampler {
    private var previous: [Int32: UInt64] = [:]
    private var current: [Int32: UInt64] = [:]
    private var pids: [Int32] = []
    private var previousNanoseconds: UInt64 = 0
    private let uid = getuid()
    private let timebase: mach_timebase_info

    public init() {
        var timebase = mach_timebase_info()
        let result = mach_timebase_info(&timebase)
        precondition(result == KERN_SUCCESS, "mach_timebase_info failed: \(result)")
        self.timebase = timebase
    }

    /// Forgets the last sample and frees the buffers, as when the menu closes, so the next sample
    /// is a fresh start.
    public func reset() {
        previous = [:]
        current = [:]
        pids = []
        previousNanoseconds = 0
    }

    /// The `count` processes that used the most CPU since the last call, most first; empty on
    /// the first call after init or `reset()`.
    public func sample(top count: Int) -> [ProcessLoad] {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        readCPUTimes()
        let elapsed = previousNanoseconds == 0 ? 0 : now - previousNanoseconds
        let top = Self.top(
            previous: previous, current: current, elapsedNanoseconds: elapsed, count: count)
        swap(&previous, &current)
        previousNanoseconds = now
        return top.map { ProcessLoad(pid: $0.pid, name: Self.name($0.pid), share: $0.share) }
    }

    /// The `count` largest shares of `elapsedNanoseconds` the processes in both samples used,
    /// most first, ties by pid; none used no CPU.
    static func top(
        previous: [Int32: UInt64], current: [Int32: UInt64], elapsedNanoseconds: UInt64,
        count: Int
    ) -> [(pid: Int32, share: Double)] {
        guard elapsedNanoseconds > 0 else { return [] }
        var shares: [(pid: Int32, share: Double)] = []
        for (pid, time) in current {
            guard let before = previous[pid], time > before else { continue }
            shares.append((pid, Double(time - before) / Double(elapsedNanoseconds)))
        }
        shares.sort { ($0.share, $1.pid) > ($1.share, $0.pid) }
        return Array(shares.prefix(count))
    }

    /// Fills `current` with each of the user's processes' user and system CPU time since it
    /// started, in nanoseconds.
    private func readCPUTimes() {
        let pidSize = MemoryLayout<Int32>.size
        let estimate = proc_listpids(UInt32(PROC_UID_ONLY), UInt32(uid), nil, 0)
        precondition(estimate > 0, "proc_listpids failed: \(String(cString: strerror(errno)))")
        // Room for processes started between the two calls.
        let capacity = Int(estimate) / pidSize + 64
        if pids.count < capacity { pids = [Int32](repeating: 0, count: capacity) }
        let bytes = proc_listpids(
            UInt32(PROC_UID_ONLY), UInt32(uid), &pids, Int32(pids.count * pidSize))
        precondition(bytes > 0, "proc_listpids failed: \(String(cString: strerror(errno)))")
        current.removeAll(keepingCapacity: true)
        for pid in pids.prefix(Int(bytes) / pidSize) where pid > 0 {
            var info = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
                }
            }
            // One that has exited since the list was made.
            guard result == 0 else { continue }
            // In Mach time units: nanoseconds on Intel, 125/3 of one on Apple silicon.
            let ticks = info.ri_user_time + info.ri_system_time
            current[pid] = ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
        }
    }

    private static func name(_ pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 2 * Int(MAXCOMLEN) + 1)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "pid \(pid)" }
        return String(
            decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
