import Testing

@testable import Base

@Test func aRingBufferKeepsTheNewestElementsOldestFirst() {
    var buffer = RingBuffer(capacity: 3, filler: 0)
    #expect(buffer.count == 0)
    buffer.append(1)
    buffer.append(2)
    #expect(buffer.count == 2)
    #expect([buffer[0], buffer[1]] == [1, 2])
    buffer.append(3)
    buffer.append(4)
    buffer.append(5)
    #expect(buffer.count == 3)
    #expect([buffer[0], buffer[1], buffer[2]] == [3, 4, 5])
}
