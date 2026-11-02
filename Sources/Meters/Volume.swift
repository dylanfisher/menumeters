import Foundation

/// A mounted volume, as the disk menu lists it.
public struct Volume: Sendable, Equatable {
    public var url: URL
    public var name: String
    public var totalBytes: Int64
    /// The space Finder calls available: free space plus what the system would purge for it.
    public var availableBytes: Int64
    /// Whether it can be ejected, as a disk image, a USB drive or a network share can.
    public var isEjectable: Bool

    public init(url: URL, name: String, totalBytes: Int64, availableBytes: Int64, isEjectable: Bool)
    {
        self.url = url
        self.name = name
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.isEjectable = isEjectable
    }

    public var usedBytes: Int64 { max(totalBytes - availableBytes, 0) }
}
