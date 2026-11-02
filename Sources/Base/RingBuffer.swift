/// A fixed-capacity history that overwrites its oldest element once full. Storage is allocated
/// once at init, so appending never allocates; meter histories use it on the sampling tick.
public struct RingBuffer<Element> {
    private var storage: [Element]
    private var start = 0
    public private(set) var count = 0

    /// Every slot starts as `filler`; it is never read back, since `count` starts at zero.
    public init(capacity: Int, filler: Element) {
        precondition(capacity > 0, "a ring buffer needs room for at least one element")
        storage = Array(repeating: filler, count: capacity)
    }

    public var capacity: Int { storage.count }

    public mutating func append(_ element: Element) {
        if count < capacity {
            storage[(start + count) % capacity] = element
            count += 1
        } else {
            storage[start] = element
            start = (start + 1) % capacity
        }
    }

    /// A copy with room for `capacity` elements, keeping the newest that fit. Allocates, so it
    /// is for a settings change, not the tick.
    public func resized(capacity: Int) -> RingBuffer {
        // Slot 0 holds an element or the filler; either serves as the new filler.
        var copy = RingBuffer(capacity: capacity, filler: storage[0])
        for index in max(0, count - capacity)..<count { copy.append(self[index]) }
        return copy
    }

    /// The element `index` places after the oldest: 0 is the oldest, `count - 1` the newest.
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count, "index \(index) is outside 0..<\(count)")
        return storage[(start + index) % capacity]
    }
}

extension RingBuffer: Sendable where Element: Sendable {}
