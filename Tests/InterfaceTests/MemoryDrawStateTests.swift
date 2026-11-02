import Meters
import Testing

@testable import Interface

private let gibibyte: UInt64 = 1 << 30

private func stats(wired: UInt64, active: UInt64) -> MemoryStats {
    MemoryStats(
        totalBytes: 16 * gibibyte, wiredBytes: wired, activeBytes: active,
        inactiveBytes: 4 * gibibyte, compressedBytes: gibibyte, pageIns: 0, pageOuts: 0)
}

@Test func thePieIsInWholePercentsOfTotalMemory() {
    let state = MemoryDrawState(stats(wired: 2 * gibibyte, active: 4 * gibibyte), display: .pie)
    #expect(state.wiredPercent == 13 && state.activePercent == 25)
    #expect(state.compressedPercent == 6 && state.inactivePercent == 25)
    #expect(state.usedTenths == 0)
}

@Test func aChangeTheDisplayDoesntShowDrawsNothingNew() {
    let before = stats(wired: 2 * gibibyte, active: 4 * gibibyte)
    // A megabyte moves the numbers by less than a tenth of a gigabyte and the pie by nothing.
    let after = stats(wired: 2 * gibibyte + (1 << 20), active: 4 * gibibyte)
    #expect(MemoryDrawState(before, display: .pie) == MemoryDrawState(after, display: .pie))
    #expect(MemoryDrawState(before, display: .number) == MemoryDrawState(after, display: .number))
    let moved = stats(wired: 3 * gibibyte, active: 4 * gibibyte)
    #expect(MemoryDrawState(before, display: .number) != MemoryDrawState(moved, display: .number))
}

@Test func theNumbersAreUsedAndFreeInGigabytes() {
    let state = MemoryDrawState(stats(wired: 2 * gibibyte, active: 4 * gibibyte), display: .number)
    #expect(MemoryDrawState.gigabytes(tenths: state.usedTenths) == "7.0G")
    #expect(MemoryDrawState.gigabytes(tenths: state.freeTenths) == "9.0G")
    #expect(MemoryDrawState.gigabytes(tenths: 1_925) == "192G")
}

@MainActor
@Test func theMemoryMeterSwitchesDisplayAndHides() {
    let meter = MemoryMeterController(config: MemoryConfig()) {}
    meter.tick()
    let pie = meter.widthPoints
    var config = MemoryConfig()
    config.display = .number
    meter.apply(config)
    #expect(meter.widthPoints != pie)
    config.isEnabled = false
    meter.apply(config)
    #expect(!meter.isVisible)
}
