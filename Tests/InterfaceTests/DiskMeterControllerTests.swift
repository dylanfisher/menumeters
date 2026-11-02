import AppKit
import Meters
import Testing

@testable import Interface

@MainActor
@Test func theLightRedrawsOnlyWhenTheActivityChanges() {
    let view = DiskMeterView()
    #expect(!view.show(.idle))
    #expect(view.show(.writing))
    #expect(!view.show(.writing))
    #expect(view.show(.idle))
}

@Test func aVolumeReadsAsItsFreeSpaceOfItsTotal() {
    let volume = Volume(
        url: URL(fileURLWithPath: "/"), name: "Macintosh HD", totalBytes: 994_000_000_000,
        availableBytes: 245_000_000_000, isEjectable: false)
    #expect(DiskMeterController.title(volume) == "Macintosh HD: 245 GB free of 994 GB")
}

@MainActor
@Test func theMenuListsTheVolumesAndOffersEjectOnlyWhereItCan() async throws {
    let meter = DiskMeterController(config: DiskConfig(), volumeStore: VolumeStore()) {}
    await meter.refreshVolumes()
    let startup = try #require(meter.volumes.first)
    let menu = NSMenu()
    meter.rebuild(menu)
    let first = try #require(menu.items.first)
    #expect(first.title == DiskMeterController.title(startup))
    #expect(first.action != nil)
    // The startup volume can't be ejected, so it has no ⌥ alternate.
    #expect(menu.items.count < 2 || !menu.items[1].isAlternate)
    var config = DiskConfig()
    config.isEnabled = false
    meter.apply(config)
    #expect(!meter.isVisible)
}
