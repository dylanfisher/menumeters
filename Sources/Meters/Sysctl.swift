import Darwin

/// Reads of `sysctlbyname` values. Each returns nil when the name doesn't exist on this Mac, as
/// `hw.nperflevels` doesn't on some Intel releases; any other failure stops the app, since the
/// names asked for are fixed and a different error means the call was written wrong.
enum Sysctl {
    static func int(_ name: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard read(name, into: &value, size: &size) else { return nil }
        // 32-bit values fill only the low bytes, and Apple silicon and Intel are little-endian.
        return Int(value)
    }

    static func string(_ name: String) -> String? {
        var size = 0
        guard read(name, into: nil, size: &size) else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard read(name, into: &bytes, size: &size) else { return nil }
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }

    static func value<T: BitwiseCopyable>(_ name: String, as type: T.Type, zero: T) -> T? {
        var value = zero
        var size = MemoryLayout<T>.size
        guard read(name, into: &value, size: &size) else { return nil }
        precondition(size == MemoryLayout<T>.size, "sysctl \(name) is \(size) bytes, not \(T.self)")
        return value
    }

    private static func read(_ name: String, into buffer: UnsafeMutableRawPointer?, size: inout Int)
        -> Bool
    {
        if sysctlbyname(name, buffer, &size, nil, 0) == 0 { return true }
        let error = errno
        precondition(error == ENOENT, "sysctl \(name) failed: \(String(cString: strerror(error)))")
        return false
    }
}
