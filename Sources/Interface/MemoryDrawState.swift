import Meters

/// What the memory meter shows, rounded to what lands on screen: whole percents of the pie's
/// wedges, or tenths of a gigabyte for the numbers. Only the display's own fields are filled, so
/// a change the display doesn't show isn't a change. The view redraws only when this changes.
struct MemoryDrawState: Equatable {
    var wiredPercent = 0
    var activePercent = 0
    var compressedPercent = 0
    var inactivePercent = 0
    /// Gibibytes times ten, as the numbers show them.
    var usedTenths = 0
    var freeTenths = 0

    init() {}

    init(_ stats: MemoryStats, display: MemoryConfig.Display) {
        switch display {
        case .pie:
            wiredPercent = Self.percent(stats.wiredBytes, of: stats.totalBytes)
            activePercent = Self.percent(stats.activeBytes, of: stats.totalBytes)
            compressedPercent = Self.percent(stats.compressedBytes, of: stats.totalBytes)
            inactivePercent = Self.percent(stats.inactiveBytes, of: stats.totalBytes)
        case .number:
            usedTenths = Self.tenths(stats.usedBytes)
            freeTenths = Self.tenths(stats.freeBytes)
        }
    }

    private static func percent(_ bytes: UInt64, of total: UInt64) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(bytes) / Double(total) * 100).rounded())
    }

    private static func tenths(_ bytes: UInt64) -> Int {
        Int((Double(bytes) / Double(1 << 30) * 10).rounded())
    }

    /// Tenths of a gibibyte as the meter writes them: `8.1G`, or `192G` from 100 up.
    static func gigabytes(tenths: Int) -> String {
        tenths >= 1_000 ? "\(tenths / 10)G" : "\(tenths / 10).\(tenths % 10)G"
    }
}
