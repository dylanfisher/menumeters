import Darwin
import Testing

@testable import Meters

@Test func usedMemoryIsWiredActiveAndCompressed() {
    var info = vm_statistics64()
    info.wire_count = 100
    info.active_count = 200
    info.inactive_count = 300
    info.compressor_page_count = 50
    info.free_count = 374
    info.pageins = 7
    info.pageouts = 3
    let stats = MemoryStats(info, pageSizeBytes: 16_384, totalBytes: 1_024 * 16_384)
    #expect(stats.wiredBytes == 100 * 16_384)
    #expect(stats.usedBytes == 350 * 16_384)
    #expect(stats.freeBytes == 674 * 16_384)
    #expect(stats.pageIns == 7 && stats.pageOuts == 3)
}

@Test func theSamplerReadsThisMacsMemory() {
    let stats = MemorySampler().stats
    #expect(stats.totalBytes > 1 << 30)
    #expect(stats.usedBytes > 0 && stats.usedBytes <= stats.totalBytes)
    let swap = MemorySampler.swap
    #expect(swap.usedBytes <= swap.totalBytes)
}
