import Darwin

/// What memory holds, in bytes, from one `host_statistics64` call. Used memory is wired, active
/// and compressed, as yujitach's fork counts it; inactive pages count as free, since the system
/// takes them back first.
public struct MemoryStats: Sendable, Equatable {
    public var totalBytes: UInt64
    public var wiredBytes: UInt64
    public var activeBytes: UInt64
    public var inactiveBytes: UInt64
    /// The memory the compressor occupies, not the larger amount it holds compressed.
    public var compressedBytes: UInt64
    /// Pages read in from and written out to disk since boot.
    public var pageIns: UInt64
    public var pageOuts: UInt64

    public init(
        totalBytes: UInt64, wiredBytes: UInt64, activeBytes: UInt64, inactiveBytes: UInt64,
        compressedBytes: UInt64, pageIns: UInt64, pageOuts: UInt64
    ) {
        self.totalBytes = totalBytes
        self.wiredBytes = wiredBytes
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.compressedBytes = compressedBytes
        self.pageIns = pageIns
        self.pageOuts = pageOuts
    }

    public static let zero = MemoryStats(
        totalBytes: 0, wiredBytes: 0, activeBytes: 0, inactiveBytes: 0, compressedBytes: 0,
        pageIns: 0, pageOuts: 0)

    /// The kernel's page counts, in pages of `pageSizeBytes`.
    public init(_ info: vm_statistics64, pageSizeBytes: UInt64, totalBytes: UInt64) {
        self.init(
            totalBytes: totalBytes,
            wiredBytes: UInt64(info.wire_count) * pageSizeBytes,
            activeBytes: UInt64(info.active_count) * pageSizeBytes,
            inactiveBytes: UInt64(info.inactive_count) * pageSizeBytes,
            compressedBytes: UInt64(info.compressor_page_count) * pageSizeBytes,
            pageIns: info.pageins, pageOuts: info.pageouts)
    }

    public var usedBytes: UInt64 { min(wiredBytes + activeBytes + compressedBytes, totalBytes) }
    public var freeBytes: UInt64 { totalBytes - usedBytes }
}
