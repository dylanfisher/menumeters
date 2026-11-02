import Darwin
import Dispatch

/// Reads every interface's 64-bit byte counters from the `NET_RT_IFLIST2` sysctl into one buffer
/// reused across samples; yujitach's fork reads the 32-bit `NET_RT_IFLIST`, whose counters wrap
/// at 4 GB. The buffer grows only when the interfaces outgrow it.
///
/// Not thread-safe; the network meter owns one and samples it on the main actor.
public final class NetworkSampler {
    private var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    private var buffer: UnsafeMutableRawPointer
    private var capacity: Int
    private var lastSampleNanoseconds: UInt64 = 0

    /// The traffic as of the last call to `sample()`; init takes the first sample.
    public private(set) var traffic = NetworkTraffic()

    public init() {
        capacity = 16_384
        buffer = .allocate(byteCount: capacity, alignment: 8)
        sample()
    }

    deinit { buffer.deallocate() }

    public func sample() {
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed =
            lastSampleNanoseconds == 0 ? 0 : Double(now - lastSampleNanoseconds) / 1e9
        lastSampleNanoseconds = now
        let length = read()
        traffic.begin(elapsedSeconds: elapsed)
        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= length {
            let header = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
            precondition(header.ifm_msglen > 0, "NET_RT_IFLIST2 sent a message of no length")
            if Int32(header.ifm_type) == RTM_IFINFO2 {
                let message = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                traffic.record(
                    index: Int(message.ifm_index), flags: message.ifm_flags,
                    type: Int32(message.ifm_data.ifi_type),
                    linkSpeedBitsPerSecond: message.ifm_data.ifi_baudrate,
                    receivedBytes: message.ifm_data.ifi_ibytes,
                    sentBytes: message.ifm_data.ifi_obytes)
            }
            offset += Int(header.ifm_msglen)
        }
        traffic.end()
    }

    /// Fills the buffer and returns how many bytes the kernel wrote, growing the buffer first
    /// when the list no longer fits.
    private func read() -> Int {
        while true {
            var length = capacity
            let result = mib.withUnsafeMutableBufferPointer {
                sysctl($0.baseAddress, u_int($0.count), buffer, &length, nil, 0)
            }
            if result == 0 { return length }
            let error = errno
            precondition(
                error == ENOMEM, "NET_RT_IFLIST2 failed: \(String(cString: strerror(error)))")
            buffer.deallocate()
            capacity *= 2
            buffer = .allocate(byteCount: capacity, alignment: 8)
        }
    }
}
