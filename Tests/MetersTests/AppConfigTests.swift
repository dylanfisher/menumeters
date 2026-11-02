import Foundation
import Testing

@testable import Meters

private func parse(_ text: String) throws(ConfigError) -> AppConfig {
    try AppConfig.parse(Data(text.utf8))
}

private func reason(_ text: String) -> String? {
    do {
        _ = try parse(text)
        return nil
    } catch {
        return error.reason
    }
}

@Test func theCPUMeterTicksEveryTwoSecondsByDefault() {
    let config = CPUConfig()
    #expect(config.intervalSeconds == 2)
    #expect(CPUConfig.intervalSecondsRange.contains(config.intervalSeconds))
}

@Test func theDefaultFileReadsBackAsTheDefaults() throws {
    let text = String(decoding: AppConfig().fileData(), as: UTF8.self)
    #expect(text.contains("\"enabled\" : true"))
    #expect(try parse(text) == AppConfig())
}

@Test func aKeyOrSectionLeftOutKeepsItsDefault() throws {
    #expect(try parse("{}") == AppConfig())
    var expected = AppConfig()
    expected.cpu.intervalSeconds = 5
    expected.cpu.isEnabled = false
    #expect(try parse(#"{"cpu": {"intervalSeconds": 5, "enabled": false}}"#) == expected)
}

@Test func anErrorNamesTheKeyAndWhatItMustBe() {
    #expect(
        reason(#"{"cpu": {"intervalSeconds": 30}}"#)
            == "cpu.intervalSeconds must be a number from 0.5 to 10, not 30")
    #expect(
        reason(#"{"cpu": {"graphWidthPoints": 33.5}}"#)
            == "cpu.graphWidthPoints must be a whole number from 11 to 88")
    #expect(reason(#"{"cpu": {"showsGraph": "yes"}}"#) == "cpu.showsGraph must be true or false")
    #expect(reason(#"{"cpu": {"interval": 1}}"#) == "unknown key cpu.interval")
    #expect(reason(#"{"battery": {}}"#) == "unknown key battery")
    #expect(
        reason(#"{"memory": {"display": "bar"}}"#)
            == #"memory.display must be one of "pie", "number", not "bar""#)
    #expect(
        reason(#"{"cpu": 1}"#) == "cpu must be a JSON object, its keys and values in braces")
    #expect(reason("[]") == "the file must be a JSON object, its keys and values in braces")
    #expect(reason(" \n") == "the file is empty: it needs a JSON object, such as {}")
    #expect(reason(#"{"cpu": "#)?.hasPrefix("the file isn't valid JSON") == true)
}

@Test func theCPUMeterCantHideBothItsParts() {
    #expect(
        reason(#"{"cpu": {"showsPercent": false, "showsGraph": false}}"#)
            == "cpu.showsPercent and cpu.showsGraph can't both be false; "
            + "set cpu.enabled to false to hide the meter")
}

@Test func theMemoryMeterIsAPieEveryTenSecondsByDefault() throws {
    #expect(try parse("{}").memory == MemoryConfig())
    #expect(MemoryConfig().display == .pie && MemoryConfig().intervalSeconds == 10)
    #expect(try parse(#"{"memory": {"display": "number"}}"#).memory.display == .number)
}

@Test func theNetworkMeterShowsArrowsEveryTwoSecondsByDefault() throws {
    let network = try parse("{}").network
    #expect(network.showsArrows && !network.showsThroughput && network.intervalSeconds == 2)
    #expect(
        reason(#"{"network": {"showsArrows": false}}"#)
            == "network.showsArrows and network.showsThroughput can't both be false; "
            + "set network.enabled to false to hide the meter")
}

@Test func aMeterThatIsOffHasNoInterval() {
    var cpu = CPUConfig()
    #expect(cpu.scheduledIntervalSeconds == 2)
    cpu.isEnabled = false
    #expect(cpu.scheduledIntervalSeconds == nil)
}

@Test func theDiskMeterTicksEveryThreeTenthsOfASecondByDefault() throws {
    #expect(try parse("{}").disk.intervalSeconds == 0.3)
    #expect(
        reason(#"{"disk": {"intervalSeconds": 0}}"#)
            == "disk.intervalSeconds must be a number from 0.1 to 5, not 0")
}
