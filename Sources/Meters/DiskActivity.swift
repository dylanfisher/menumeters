/// Whether the disks read or wrote between two samples.
public enum DiskActivity: Sendable, Equatable {
    case idle, reading, writing, readingAndWriting

    /// The activity between two samples of the bytes all disks have read and written. Totals
    /// that went down mean a disk went away, which says nothing about the others: idle.
    public init(previous: DiskTotals, current: DiskTotals) {
        let read = current.readBytes > previous.readBytes
        let written = current.writtenBytes > previous.writtenBytes
        switch (read, written) {
        case (true, true): self = .readingAndWriting
        case (true, false): self = .reading
        case (false, true): self = .writing
        case (false, false): self = .idle
        }
    }
}

/// The bytes every disk has read and written since it appeared.
public struct DiskTotals: Sendable, Equatable {
    public var readBytes: UInt64
    public var writtenBytes: UInt64

    public init(readBytes: UInt64, writtenBytes: UInt64) {
        self.readBytes = readBytes
        self.writtenBytes = writtenBytes
    }

    public static let zero = DiskTotals(readBytes: 0, writtenBytes: 0)
}
