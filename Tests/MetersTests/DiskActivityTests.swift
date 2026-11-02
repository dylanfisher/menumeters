import Foundation
import Testing

@testable import Meters

@Test func activityComesFromWhichTotalsGrew() {
    let before = DiskTotals(readBytes: 100, writtenBytes: 100)
    let read = DiskTotals(readBytes: 200, writtenBytes: 100)
    let both = DiskTotals(readBytes: 200, writtenBytes: 300)
    #expect(DiskActivity(previous: before, current: before) == .idle)
    #expect(DiskActivity(previous: before, current: read) == .reading)
    #expect(DiskActivity(previous: read, current: both) == .writing)
    #expect(DiskActivity(previous: before, current: both) == .readingAndWriting)
    // A disk going away lowers the totals.
    #expect(DiskActivity(previous: both, current: before) == .idle)
}

@Test func theSamplerWatchesThisMacsDisksAndSeesAWrite() throws {
    let sampler = DiskActivitySampler()
    #expect(sampler.diskCount > 0)
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent("DiskActivityTests-\(UUID().uuidString)")
    try Data().write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let handle = try FileHandle(forWritingTo: file)
    defer { try? handle.close() }
    var sawWrite = false
    // Other processes' writes may land in the first sample; a write the test syncs lands in
    // the second.
    for _ in 0..<20 where !sawWrite {
        sampler.sample()
        try handle.write(contentsOf: Data(repeating: 1, count: 1 << 20))
        try handle.synchronize()
        sampler.sample()
        sawWrite = [.writing, .readingAndWriting].contains(sampler.activity)
    }
    #expect(sawWrite)
}

@Test func theStartupVolumeIsListedFirst() async throws {
    let volumes = await VolumeStore().volumes()
    let startup = try #require(volumes.first)
    #expect(startup.url.path == "/")
    #expect(startup.totalBytes > startup.availableBytes && startup.availableBytes > 0)
    #expect(!startup.isEjectable)
}
