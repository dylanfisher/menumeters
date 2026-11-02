import Darwin

/// Each network interface's byte counters and rates, kept in arrays indexed by interface index
/// and grown only when an interface with a higher index appears, so a sample allocates nothing.
/// Pure, so the rules are tested without the kernel; `NetworkSampler` feeds it.
///
/// The meter counts only interfaces of Ethernet type that are up, Wi-Fi among them: a VPN's
/// tunnel carries traffic an Ethernet-type interface carries again, and the loopback carries
/// none that leaves the Mac (docs/decisions/0004-network-meter.md).
public struct NetworkTraffic: Sendable {
    /// One interface as of the last sample.
    public struct Interface: Sendable, Equatable {
        /// False for an index no sample has reported, or one the last sample didn't.
        public var isPresent = false
        public var isUp = false
        /// Whether the meter's total counts this interface.
        public var isCounted = false
        /// Bytes since the interface came up.
        public var receivedBytes: UInt64 = 0
        public var sentBytes: UInt64 = 0
        /// Bytes per second between the last two samples; zero after the first.
        public var receiveRate: Double = 0
        public var sendRate: Double = 0
        /// The highest rates since the app started.
        public var peakReceiveRate: Double = 0
        public var peakSendRate: Double = 0
        /// The link speed the driver reports, in bits per second; zero when it reports none.
        public var linkSpeedBitsPerSecond: UInt64 = 0
        /// Whether `receivedBytes` and `sentBytes` are from a sample before this one.
        var hasCounters = false
    }

    /// Indexed by interface index; index 0 is never an interface.
    public private(set) var interfaces: [Interface] = Array(repeating: Interface(), count: 32)
    /// The counted interfaces' rates added up, in bytes per second.
    public private(set) var receiveRate: Double = 0
    public private(set) var sendRate: Double = 0
    private var elapsedSeconds: Double = 0

    public init() {}

    /// Starts a sample taken `elapsedSeconds` after the one before.
    public mutating func begin(elapsedSeconds: Double) {
        self.elapsedSeconds = elapsedSeconds
        for index in interfaces.indices { interfaces[index].isPresent = false }
        receiveRate = 0
        sendRate = 0
    }

    /// Records one interface's counters, as `if_msghdr2` reports them.
    public mutating func record(
        index: Int, flags: Int32, type: Int32, linkSpeedBitsPerSecond: UInt64,
        receivedBytes: UInt64, sentBytes: UInt64
    ) {
        if index >= interfaces.count {
            interfaces += Array(repeating: Interface(), count: index + 1 - interfaces.count)
        }
        var interface = interfaces[index]
        interface.isPresent = true
        interface.isUp = flags & IFF_UP != 0
        interface.isCounted = interface.isUp && flags & IFF_LOOPBACK == 0 && type == IFT_ETHER
        interface.linkSpeedBitsPerSecond = linkSpeedBitsPerSecond
        // Counters that went down belong to a new interface at the same index.
        if interface.hasCounters, elapsedSeconds > 0, receivedBytes >= interface.receivedBytes,
            sentBytes >= interface.sentBytes
        {
            interface.receiveRate = Double(receivedBytes - interface.receivedBytes) / elapsedSeconds
            interface.sendRate = Double(sentBytes - interface.sentBytes) / elapsedSeconds
        } else {
            interface.receiveRate = 0
            interface.sendRate = 0
        }
        interface.peakReceiveRate = max(interface.peakReceiveRate, interface.receiveRate)
        interface.peakSendRate = max(interface.peakSendRate, interface.sendRate)
        interface.receivedBytes = receivedBytes
        interface.sentBytes = sentBytes
        interface.hasCounters = true
        interfaces[index] = interface
        if interface.isCounted {
            receiveRate += interface.receiveRate
            sendRate += interface.sendRate
        }
    }

    /// Ends a sample: an interface it didn't report has gone.
    public mutating func end() {
        for index in interfaces.indices where !interfaces[index].isPresent {
            interfaces[index] = Interface()
        }
    }
}
