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

@Test func resizingKeepsTheNewestElementsThatFit() {
    var buffer = RingBuffer(capacity: 4, filler: 0)
    for value in 1...6 { buffer.append(value) }
    let smaller = buffer.resized(capacity: 2)
    #expect(smaller.capacity == 2)
    #expect([smaller[0], smaller[1]] == [5, 6])
    var larger = buffer.resized(capacity: 6)
    #expect(larger.count == 4)
    larger.append(7)
    #expect([larger[0], larger[4]] == [3, 7])
}
