import Testing

@testable import Interface

@Test func theNoticeNamesTheHiddenMeters() {
    #expect(HiddenMeterNotice.message(hidden: ["CPU"]) == "macOS is hiding the CPU meter")
    #expect(
        HiddenMeterNotice.message(hidden: ["CPU", "Disk"])
            == "macOS is hiding the CPU and Disk meters")
    #expect(
        HiddenMeterNotice.message(hidden: ["CPU", "Memory", "Disk"])
            == "macOS is hiding the CPU, Memory, and Disk meters")
}
