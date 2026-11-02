import Base
import Meters
import Testing

@testable import Interface

private func history(_ loads: [CoreLoad], capacity: Int) -> RingBuffer<CoreLoad> {
    var buffer = RingBuffer(capacity: capacity, filler: CoreLoad.zero)
    for load in loads { buffer.append(load) }
    return buffer
}

@Test func barsAreRightAlignedAndMeasuredInDevicePixels() {
    var state = CPUDrawState(rowCount: 1, columnCount: 3)
    let loads = [CoreLoad(user: 0.5, system: 0.25)]
    state.update(histories: [history(loads, capacity: 3)], rowHeightPoints: 10, scale: 2)
    #expect(state.column(row: 0, column: 0) == .init())
    #expect(state.column(row: 0, column: 1) == .init())
    #expect(state.column(row: 0, column: 2) == .init(systemPixels: 5, totalPixels: 15))
    #expect(state.percents == [75])
}

@Test func aChangeSmallerThanAPixelDrawsNothingNew() {
    var drawn = CPUDrawState(rowCount: 1, columnCount: 2)
    var next = drawn
    let steady = [CoreLoad(user: 0.5, system: 0), CoreLoad(user: 0.5, system: 0)]
    drawn.update(histories: [history(steady, capacity: 2)], rowHeightPoints: 16, scale: 1)
    let nudged = [CoreLoad(user: 0.5, system: 0), CoreLoad(user: 0.502, system: 0)]
    next.update(histories: [history(nudged, capacity: 2)], rowHeightPoints: 16, scale: 1)
    #expect(next == drawn)
    let moved = [CoreLoad(user: 0.5, system: 0), CoreLoad(user: 0.6, system: 0)]
    next.update(histories: [history(moved, capacity: 2)], rowHeightPoints: 16, scale: 1)
    #expect(next != drawn)
}

@Test func eachRowShowsItsOwnHistory() {
    var state = CPUDrawState(rowCount: 2, columnCount: 1)
    let performance = history([CoreLoad(user: 1, system: 0)], capacity: 1)
    let efficiency = history([CoreLoad(user: 0, system: 0.1)], capacity: 1)
    state.update(histories: [performance, efficiency], rowHeightPoints: 10, scale: 1)
    #expect(state.percents == [100, 10])
    #expect(state.column(row: 0, column: 0) == .init(systemPixels: 0, totalPixels: 10))
    #expect(state.column(row: 1, column: 0) == .init(systemPixels: 1, totalPixels: 1))
}

@Test func uptimeReadsInDaysHoursAndMinutes() {
    #expect(CPUMeterController.uptime(3 * 86_400 + 4 * 3_600 + 5 * 60 + 9) == "3d 4h 5m")
    #expect(CPUMeterController.uptime(4 * 3_600 + 59) == "4h 0m")
}
